const crypto = require('crypto');
const { supabaseAdmin } = require('../config/supabase');
const { sendWhatsAppText } = require('../config/openwa');
const { verifyFirebaseIdToken } = require('../config/firebase');

const OTP_TTL_SECONDS = parseInt(process.env.OTP_TTL_SECONDS || '300', 10);
const OTP_COOLDOWN_SECONDS = parseInt(process.env.OTP_COOLDOWN_SECONDS || '60', 10);
const OTP_MAX_ATTEMPTS = parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10);
const QA_OTP_ENABLED = (process.env.QA_OTP_ENABLED || 'true') === 'true';
const FALLBACK_OTP = process.env.FALLBACK_OTP || '11111';
const ADMIN_PHONES = (process.env.ADMIN_PHONES || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function isValidPhone(phone) {
  return /^[6-9]\d{9}$/.test(phone);
}

function syntheticEmail(phone) {
  return `poolit_${phone}@poolit.in`;
}

function extractTokenHash(value) {
  if (!value || typeof value !== 'string') return null;
  const direct = value.match(/[?&](?:token|token_hash)=([^&#]+)/);
  if (direct) return decodeURIComponent(direct[1]);
  try {
    const u = new URL(value);
    const q = u.searchParams.get('token') || u.searchParams.get('token_hash');
    if (q) return q;
    const params = new URLSearchParams(u.hash.replace(/^#/, ''));
    const h = params.get('token') || params.get('token_hash');
    if (h) return h;
  } catch (_) {}
  return null;
}

// Look up an existing auth user by phone. Uses the Supabase Admin API only
// (no direct DB access), so it does not depend on DATABASE_URL/Prisma.
async function findAuthUserByPhone(phone) {
  const email = syntheticEmail(phone);
  const normalizedPhone = `91${phone}`;

  try {
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('phone', phone)
      .maybeSingle();
    if (profile && profile.id) {
      const { data } = await supabaseAdmin.auth.admin.getUserById(profile.id);
      if (data && data.user) return data.user;
    }
  } catch (err) {
    console.error('findAuthUserByPhone (profiles) error:', err.message);
  }

  try {
    let page = 1;
    while (page <= 50) {
      const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) throw error;
      const users = (data && data.users) || [];
      const match = users.find(
        (u) =>
          u.email === email ||
          u.phone === normalizedPhone ||
          u.phone === `+${normalizedPhone}`
      );
      if (match) return match;
      if (users.length < 200) break;
      page += 1;
    }
  } catch (err) {
    console.error('findAuthUserByPhone (listUsers) error:', err.message);
  }

  return null;
}

// Look up an existing auth user by email using the Admin API. Supabase does
// not expose a getUserByEmail helper, so page through the user list.
async function findAuthUserByEmail(email) {
  const target = String(email || '').trim().toLowerCase();
  if (!target) return null;

  try {
    let page = 1;
    while (page <= 50) {
      const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) throw error;
      const users = (data && data.users) || [];
      const match = users.find((u) => (u.email || '').toLowerCase() === target);
      if (match) return match;
      if (users.length < 200) break;
      page += 1;
    }
  } catch (err) {
    console.error('findAuthUserByEmail error:', err.message);
  }

  return null;
}

function extractLoginToken(linkData) {
  const props = linkData?.properties || {};
  return (
    props.hashed_token ||
    linkData?.hashed_token ||
    props.token_hash ||
    linkData?.token_hash ||
    extractTokenHash(props.action_link) ||
    extractTokenHash(linkData?.action_link) ||
    null
  );
}

async function generateLoginToken(authUser, fallbackEmail) {
  const { data: linkData, error: linkErr } = await supabaseAdmin.auth.admin.generateLink({
    type: 'magiclink',
    email: authUser.email || fallbackEmail,
  });
  if (linkErr) throw linkErr;

  const tokenHash = extractLoginToken(linkData);
  if (!tokenHash) {
    const err = new Error('Could not generate a login token');
    err.status = 500;
    throw err;
  }
  return tokenHash;
}

async function sendOtp(phone) {
  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  const expiresAt = new Date(Date.now() + OTP_TTL_SECONDS * 1000).toISOString();

  const { data: existing, error: existingErr } = await supabaseAdmin
    .from('otp_requests')
    .select('last_sent_at')
    .eq('phone', phone)
    .maybeSingle();

  if (existingErr) {
    throw new Error('Failed to check OTP cooldown');
  }

  if (
    existing &&
    Date.now() - new Date(existing.last_sent_at).getTime() < OTP_COOLDOWN_SECONDS * 1000
  ) {
    const err = new Error('Please wait before requesting another OTP');
    err.status = 429;
    throw err;
  }

  const { error: upsertErr } = await supabaseAdmin.from('otp_requests').upsert(
    {
      phone,
      code_hash: sha256(code),
      expires_at: expiresAt,
      attempts: 0,
      last_sent_at: new Date().toISOString(),
    },
    { onConflict: 'phone' }
  );

  if (upsertErr) {
    console.error('OTP upsert error:', upsertErr);
    throw new Error('Failed to store OTP');
  }

  try {
    await sendWhatsAppText(
      phone,
      `Your PoolIT OTP is ${code}. Valid for ${Math.round(OTP_TTL_SECONDS / 60)} minutes.`
    );
  } catch (err) {
    console.error('OpenWA delivery failed:', err.message);
    if (process.env.OPENWA_REQUIRED === 'true') {
      const deliveryErr = new Error('Failed to send OTP via WhatsApp');
      deliveryErr.status = 503;
      throw deliveryErr;
    }
  }

  return { expires_in: OTP_TTL_SECONDS };
}

async function verifyOtp(phone, otp) {
  const { data: record, error: fetchErr } = await supabaseAdmin
    .from('otp_requests')
    .select('*')
    .eq('phone', phone)
    .maybeSingle();

  if (fetchErr) {
    throw new Error('Failed to check OTP');
  }

  const now = Date.now();

  if (!record) {
    const err = new Error('No OTP request found for this phone');
    err.status = 400;
    throw err;
  }

  if (new Date(record.expires_at).getTime() < now) {
    await supabaseAdmin.from('otp_requests').delete().eq('phone', phone);
    const err = new Error('OTP expired');
    err.status = 400;
    throw err;
  }

  if (record.attempts >= OTP_MAX_ATTEMPTS) {
    const err = new Error('Too many attempts, request a new OTP');
    err.status = 429;
    throw err;
  }

  const qaMatch = QA_OTP_ENABLED && otp === FALLBACK_OTP;
  const realMatch = sha256(otp) === record.code_hash;

  if (!qaMatch && !realMatch) {
    await supabaseAdmin
      .from('otp_requests')
      .update({ attempts: record.attempts + 1 })
      .eq('phone', phone);
    const err = new Error('Invalid OTP');
    err.status = 400;
    throw err;
  }

  await supabaseAdmin.from('otp_requests').delete().eq('phone', phone);

  const email = syntheticEmail(phone);
  const isAdmin = ADMIN_PHONES.includes(phone);

  let authUser = await findAuthUserByPhone(phone);

  if (authUser) {
    const { data: updated, error: updErr } = await supabaseAdmin.auth.admin.updateUserById(
      authUser.id,
      {
        email: authUser.email || email,
        phone: `+91${phone}`,
        phone_confirm: true,
        email_confirm: true,
        user_metadata: { name: '', phone, is_admin: isAdmin },
      }
    );
    if (updErr) throw updErr;
    authUser = updated?.user || updated;
  } else {
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      phone: `+91${phone}`,
      password: crypto.randomBytes(16).toString('hex'),
      email_confirm: true,
      phone_confirm: true,
      user_metadata: { name: '', phone, is_admin: isAdmin },
    });
    if (createErr) {
      // The user may already exist (e.g. created before profiles existed).
      // Recover instead of failing the login.
      if (/already|exist|registered/i.test(createErr.message || '')) {
        const found = await findAuthUserByPhone(phone);
        if (!found) throw createErr;
        const { data: updated, error: updErr } = await supabaseAdmin.auth.admin.updateUserById(
          found.id,
          {
            email: found.email || email,
            phone: `+91${phone}`,
            phone_confirm: true,
            email_confirm: true,
            user_metadata: { name: '', phone, is_admin: isAdmin },
          }
        );
        if (updErr) throw updErr;
        authUser = updated?.user || updated;
      } else {
        throw createErr;
      }
    } else {
      authUser = created?.user || created;
    }
  }

  const { error: profErr } = await supabaseAdmin.from('profiles').upsert(
    {
      id: authUser.id,
      phone,
      is_admin: isAdmin,
      full_name: authUser.user_metadata?.name || '',
    },
    { onConflict: 'id' }
  );
  if (profErr) throw profErr;

  const tokenHash = await generateLoginToken(authUser, email);

  return {
    token_hash: tokenHash,
    user: {
      id: authUser.id,
      phone,
      name: authUser.user_metadata?.name || '',
      is_admin: isAdmin,
    },
  };
}

// Sign in with a Firebase ID token (Google provider), then bridge the identity
// into a Supabase session so the existing RLS/data layer keeps working.
async function signInWithFirebase(idToken) {
  const decoded = await verifyFirebaseIdToken(idToken);
  const provider = decoded.firebase?.sign_in_provider;
  if (provider && provider !== 'google.com') {
    const err = new Error('Only Google sign-in is supported');
    err.status = 403;
    throw err;
  }

  const email = (decoded.email || '').trim().toLowerCase();
  const firebaseUid = decoded.uid;
  const name = (decoded.name || '').trim();
  const picture = decoded.picture || '';

  if (!email) {
    const err = new Error('This Google account does not have an email address');
    err.status = 400;
    throw err;
  }

  if (decoded.email_verified === false) {
    const err = new Error('This Google account email is not verified');
    err.status = 403;
    throw err;
  }

  let authUser = await findAuthUserByEmail(email);

  if (authUser) {
    const metadata = {
      ...(authUser.user_metadata || {}),
      firebase_uid: firebaseUid,
      auth_provider: 'google',
    };
    if (name) metadata.name = name;
    if (picture) metadata.profile_pic = picture;

    const { data: updated, error: updErr } = await supabaseAdmin.auth.admin.updateUserById(
      authUser.id,
      { email_confirm: true, user_metadata: metadata }
    );
    if (updErr) throw updErr;
    authUser = updated?.user || updated || authUser;
  } else {
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: crypto.randomBytes(16).toString('hex'),
      email_confirm: true,
      user_metadata: {
        name,
        profile_pic: picture,
        firebase_uid: firebaseUid,
        auth_provider: 'google',
      },
    });

    if (createErr) {
      if (/already|exist|registered/i.test(createErr.message || '')) {
        const found = await findAuthUserByEmail(email);
        if (!found) throw createErr;
        const { data: updated, error: updErr } = await supabaseAdmin.auth.admin.updateUserById(
          found.id,
          {
            email_confirm: true,
            user_metadata: {
              ...(found.user_metadata || {}),
              name: name || found.user_metadata?.name || '',
              profile_pic: picture || found.user_metadata?.profile_pic || '',
              firebase_uid: firebaseUid,
              auth_provider: 'google',
            },
          }
        );
        if (updErr) throw updErr;
        authUser = updated?.user || updated || found;
      } else {
        throw createErr;
      }
    } else {
      authUser = created?.user || created;
    }
  }

  const profileFields = { id: authUser.id };
  if (name) profileFields.full_name = name;
  if (picture) profileFields.avatar_url = picture;

  const { error: profErr } = await supabaseAdmin
    .from('profiles')
    .upsert(profileFields, { onConflict: 'id' });
  if (profErr) throw profErr;

  const tokenHash = await generateLoginToken(authUser, email);

  return {
    token_hash: tokenHash,
    user: {
      id: authUser.id,
      email,
      name: name || authUser.user_metadata?.name || '',
      profile_pic: picture || authUser.user_metadata?.profile_pic || '',
    },
  };
}

exports.firebaseLogin = async (req, res) => {
  try {
    const { id_token: idToken } = req.body || {};
    if (!idToken || typeof idToken !== 'string') {
      return res.status(400).json({ error: 'Firebase ID token is required' });
    }

    const result = await signInWithFirebase(idToken);
    res.json({ message: 'Login successful', ...result });
  } catch (error) {
    console.error('Firebase login error:', error);
    let status = error.status;
    if (!status) {
      switch (error.code) {
        case 'auth/id-token-expired':
        case 'auth/id-token-revoked':
        case 'auth/invalid-id-token':
        case 'auth/argument-error':
          status = 401;
          break;
        case 'auth/user-disabled':
          status = 403;
          break;
        default:
          status = 500;
      }
    }
    res.status(status).json({ error: error.message || 'Firebase login failed' });
  }
};

exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body || {};
    if (!phone || !isValidPhone(String(phone))) {
      return res.status(400).json({ error: 'Valid 10-digit phone number required' });
    }

    const result = await sendOtp(String(phone));
    res.json({ message: 'OTP sent to WhatsApp', ...result });
  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(error.status || 500).json({ error: error.message || 'Failed to send OTP' });
  }
};

exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body || {};
    if (!phone || !otp) {
      return res.status(400).json({ error: 'Phone and OTP are required' });
    }

    const digits = String(phone);
    if (!isValidPhone(digits)) {
      return res.status(400).json({ error: 'Valid 10-digit phone number required' });
    }

    const result = await verifyOtp(digits, String(otp));
    res.json({ message: 'Login successful', ...result });
  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(error.status || 500).json({ error: error.message || 'Verification failed' });
  }
};
const crypto = require('crypto');
const { supabaseAdmin } = require('../config/supabase');
const prisma = require('../config/database');
const { sendWhatsAppText } = require('../config/openwa');

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

function extractTokenHash(value) {
  if (!value) return null;
  if (typeof value === 'string') {
    const direct = value.match(/token_hash=([^&#]+)/);
    if (direct) return decodeURIComponent(direct[1]);
    try {
      const u = new URL(value);
      const q = u.searchParams.get('token_hash');
      if (q) return q;
      const params = new URLSearchParams(u.hash.replace(/^#/, ''));
      const h = params.get('token_hash');
      if (h) return h;
    } catch (_) {}
  }
  return null;
}

async function findAuthUserByPhone(phone) {
  try {
    const rows = await prisma.$queryRaw`
      select id, email, phone from auth.users where phone = ${`+91${phone}`} limit 1
    `;
    return rows && rows.length ? rows[0] : null;
  } catch (err) {
    console.error('findAuthUserByPhone error:', err.message);
    return null;
  }
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

  const email = `poolit_${phone}@poolit.in`;
  const isAdmin = ADMIN_PHONES.includes(phone);

  let existing = await findAuthUserByPhone(phone);
  let authUser;

  if (existing) {
    const { data: updated, error: updErr } = await supabaseAdmin.auth.admin.updateUserById(
      existing.id,
      {
        email: existing.email || email,
        phone: `+91${phone}`,
        phone_confirm: true,
        email_confirm: true,
        user_metadata: { name: '', phone, is_admin: isAdmin },
      }
    );
    if (updErr) throw updErr;
    authUser = updated;
  } else {
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      phone: `+91${phone}`,
      password: crypto.randomBytes(16).toString('hex'),
      email_confirm: true,
      phone_confirm: true,
      user_metadata: { name: '', phone, is_admin: isAdmin },
    });
    if (createErr) throw createErr;
    authUser = created;
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

  const { data: linkData, error: linkErr } = await supabaseAdmin.auth.admin.generateLink({
    type: 'magiclink',
    email: authUser.email || email,
  });
  if (linkErr) throw linkErr;

  const link = linkData?.user?.action_links?.[0] || {};
  const tokenHash =
    linkData?.token_hash ||
    linkData?.properties?.token_hash ||
    link.token_hash ||
    extractTokenHash(linkData?.action_link) ||
    extractTokenHash(linkData?.properties?.action_link) ||
    extractTokenHash(link.action_link);

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
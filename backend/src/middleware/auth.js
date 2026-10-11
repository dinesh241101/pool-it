const { createClient } = require('@supabase/supabase-js');
const prisma = require('../config/database');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const token = authHeader.split(' ')[1];

    const supabaseClient = createClient(
      supabaseUrl || 'http://localhost',
      supabaseAnonKey || 'missing-anon-key',
      {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { Authorization: `Bearer ${token}` } },
      }
    );

    const { data: { user: supabaseUser }, error } = await supabaseClient.auth.getUser(token);

    if (error || !supabaseUser) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    const userId = supabaseUser.id;

    let dbUser = await prisma.user.findUnique({ where: { id: userId } });

    if (!dbUser) {
      dbUser = await prisma.user.create({
        data: {
          id: userId,
          phone: supabaseUser.phone || '',
          name: supabaseUser.user_metadata?.name || '',
          email: supabaseUser.email || '',
        },
      });
    }

    req.user = {
      id: dbUser.id,
      name: dbUser.name,
      phone: dbUser.phone,
      email: dbUser.email,
      isDriver: dbUser.isDriver,
      profilePic: dbUser.profilePic,
    };
    req.supabaseUserId = userId;

    next();
  } catch (error) {
    console.error('Auth error:', error);
    if (error.message?.includes('AuthApiError') || error.status === 401) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    next(error);
  }
};

module.exports = { authenticate };

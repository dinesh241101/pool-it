const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

let app = null;

function getFirebaseApp() {
  if (app) return app;

  const existing = getApps();
  if (existing.length > 0) {
    app = existing[0];
    return app;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    app = initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
      projectId,
    });
    return app;
  }

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    app = initializeApp();
    return app;
  }

  const err = new Error('Google sign-in is not configured on the server');
  err.status = 503;
  throw err;
}

async function verifyFirebaseIdToken(idToken) {
  const auth = getAuth(getFirebaseApp());
  return auth.verifyIdToken(idToken, true);
}

module.exports = { getFirebaseApp, verifyFirebaseIdToken };

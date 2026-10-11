const OPENWA_BASE_URL = process.env.OPENWA_BASE_URL || 'http://localhost:2785';
const OPENWA_SESSION_ID = process.env.OPENWA_SESSION_ID || 'default';
const OPENWA_API_KEY = process.env.OPENWA_API_KEY || '';

async function sendWhatsAppText(phoneDigits, text) {
  const chatId = `${phoneDigits}@c.us`;

  const response = await fetch(
    `${OPENWA_BASE_URL}/api/sessions/${OPENWA_SESSION_ID}/messages/send-text`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(OPENWA_API_KEY ? { 'X-API-Key': OPENWA_API_KEY } : {}),
      },
      body: JSON.stringify({ chatId, text }),
    }
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenWA send-text failed (${response.status}): ${body}`);
  }

  return response.json();
}

module.exports = { sendWhatsAppText };
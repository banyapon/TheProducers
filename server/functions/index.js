// Cloudinary upload signer for The Producers (Firebase Cloud Functions v2).
// The game sends {params} + "Authorization: Bearer <Firebase ID token>"; we verify the token,
// only allow uploads into the caller's own folder, and sign with the secret kept server-side.
//
// Setup:
//   firebase functions:secrets:set CLOUDINARY_API_SECRET
//   (set CLOUDINARY_API_KEY in functions/.env)
//   firebase deploy --only functions
// Then in config/secrets.cfg:  signing_mode="server"  signing_url="<function URL>"

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

const CLOUDINARY_API_KEY = defineString("CLOUDINARY_API_KEY");
const CLOUDINARY_API_SECRET = defineSecret("CLOUDINARY_API_SECRET");
const ROOT_FOLDER = "the_producers";
const ALLOWED_PARAMS = ["folder", "public_id", "tags", "timestamp"];

exports.signCloudinaryUpload = onRequest({ secrets: [CLOUDINARY_API_SECRET], cors: true }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });

  const match = (req.get("Authorization") || "").match(/^Bearer (.+)$/);
  if (!match) return res.status(401).json({ error: "missing ID token" });
  let uid;
  try {
    uid = (await admin.auth().verifyIdToken(match[1])).uid;
  } catch (e) {
    return res.status(401).json({ error: "invalid ID token" });
  }

  const params = (req.body && req.body.params) || {};
  const destroying = req.body?.operation === "destroy";
  const allowed = destroying ? ["public_id", "timestamp", "invalidate"] : ALLOWED_PARAMS;
  for (const key of Object.keys(params)) {
    if (!allowed.includes(key)) return res.status(400).json({ error: `param not allowed: ${key}` });
  }
  const ownedPath = String(destroying ? params.public_id || "" : params.folder || "");
  if (!ownedPath.startsWith(`${ROOT_FOLDER}/${uid}/`) || ownedPath.includes("..") || ownedPath.includes("\\")) {
    return res.status(403).json({ error: "folder must belong to the signed-in player" });
  }
  const ts = Number(params.timestamp);
  if (!ts || Math.abs(Date.now() / 1000 - ts) > 600) return res.status(400).json({ error: "stale timestamp" });

  const toSign = Object.keys(params).sort().map((k) => `${k}=${params[k]}`).join("&");
  const signature = crypto.createHash("sha1").update(toSign + CLOUDINARY_API_SECRET.value()).digest("hex");
  return res.json({ signature, api_key: CLOUDINARY_API_KEY.value() });
});

// The Firebase *web* config — public by design. It is compiled into every JS
// bundle that uses it, so hiding it buys nothing; the access control that
// matters is on the Firebase project, not on these six strings.
//
// `messages-34023` is this product's project: it is the same project id as the
// API's service account (backend/.firebase-service-account.json), and the two
// have to match or a browser registers a push token with a project the server
// never sends to.
//
// Checked in on purpose, and the only copy. index.html and push/sw.js both
// read it rather than carrying their own — a config the client and the server
// must agree on is exactly the kind that must not exist twice.
globalThis.lamazonFirebaseConfig = {
  apiKey: "AIzaSyBGvYciGBw1hGyAiOE2OjOEbeiuonkfsvk",
  authDomain: "messages-34023.firebaseapp.com",
  projectId: "messages-34023",
  storageBucket: "messages-34023.firebasestorage.app",
  messagingSenderId: "712322562286",
  appId: "1:712322562286:web:cbbb820967ae46611b1bff",
};

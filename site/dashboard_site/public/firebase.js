// firebase.js — shared config, auth helpers, role-based routing (no Cloud Functions)
import { initializeApp }   from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import { getAuth, onAuthStateChanged, signOut }
  from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import { getFirestore, doc, getDoc }
  from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

const firebaseConfig = {
  apiKey:            "AIzaSyC6r1sMMfdWqcSB2_-FH7ZsySKrPLVogrk",
  authDomain:        "algoquest-3f812.firebaseapp.com",
  databaseURL:       "https://algoquest-3f812-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId:         "algoquest-3f812",
  storageBucket:     "algoquest-3f812.firebasestorage.app",
  messagingSenderId: "261007565650",
  appId:             "1:261007565650:web:f34dc90b3dae4a4c01508b",
};

export const app  = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db   = getFirestore(app);

// Teacher registration code — change this to whatever you want
export const TEACHER_CODE = "ALGO-TEACH-2025";

// Read role from Firestore and redirect to correct dashboard
export async function redirectToDashboard(user) {
  try {
    const snap = await getDoc(doc(db, "users", user.uid));
    const role = snap.exists() ? (snap.data().role || "student") : "student";
    if (role === "teacher") {
      window.location.href = "teacher.html";
    } else {
      window.location.href = "dashboard.html";
    }
  } catch (e) {
    window.location.href = "dashboard.html";
  }
}

// Called on index.html — skip login if already signed in
export function redirectIfAuthed() {
  onAuthStateChanged(auth, async user => {
    if (user) await redirectToDashboard(user);
  });
}

// Called on dashboard.html and teacher.html — redirect unauthed to login
export function requireAuth(callback) {
  onAuthStateChanged(auth, user => {
    if (!user) {
      window.location.href = "index.html";
    } else {
      callback(user);
    }
  });
}

// Logout and go back to login
export async function logout() {
  await signOut(auth);
  window.location.href = "index.html";
}

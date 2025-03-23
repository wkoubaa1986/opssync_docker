importScripts("https://www.gstatic.com/firebasejs/10.3.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.3.0/firebase-messaging-compat.js");

// ✅ Initialize Firebase
firebase.initializeApp({
    apiKey: "AIzaSyCqmdRjw1wPOPus6H9wc7M9IW5yR6GBEYA",
    authDomain: "erpnext-raven.firebaseapp.com",
    projectId: "erpnext-raven",
    storageBucket: "erpnext-raven.appspot.com",
    messagingSenderId: "460641215538",
    appId: "1:460641215538:web:39b897423f4c3ea1d4c82b",
    measurementId: "G-RZDT9SV47P"
});

const messaging = firebase.messaging();

// ✅ Ensure Service Worker Stays Active
self.addEventListener("install", (event) => {
    console.log("🔄 Service Worker Installed");
    self.skipWaiting();
});

self.addEventListener("activate", (event) => {
    console.log("🚀 Service Worker Activated");
    return self.clients.claim();
});

// ✅ Handle Background Push Notifications
messaging.onBackgroundMessage((payload) => {
    console.log("📩 Background Message received:", payload);

    if (payload && payload.notification) {
        console.log("✅ Notification Data Found:", payload.notification);

        const notificationTitle = payload.notification.title || "Default Title";
        const notificationOptions = {
            body: payload.notification.body || "Default Body",
            icon: payload.notification.icon || "/firebase-logo.png",
            data: { click_action: payload.notification.click_action || "https://aquaworldservicing.opssync.pro" }
        };

        console.log("🛑 Attempting to show notification...");
        self.registration.showNotification(notificationTitle, notificationOptions)
            .then(() => console.log("✅ Notification displayed successfully"))
            .catch((error) => console.error("❌ Error displaying notification:", error));
    } else {
        console.warn("⚠ No notification data in payload! Check if FCM is sending 'data' messages instead.");
    }
});

// ✅ Handle Notification Clicks
self.addEventListener("notificationclick", (event) => {
    console.log("🔔 Notification clicked: ", event.notification);
    event.notification.close();
    event.waitUntil(
        clients.openWindow(event.notification.data.click_action)
    );
});

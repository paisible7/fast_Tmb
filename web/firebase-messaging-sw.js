/* eslint-disable no-undef */
// Firebase Messaging service worker for Flutter Web
// This must be at the root of the web folder: web/firebase-messaging-sw.js

importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in the messagingSenderId.
firebase.initializeApp({
  apiKey: 'AIzaSyAUCW_cUN7nPocgUuxU0IYYfKC6ohT4XsA',
  appId: '1:398834852035:web:534467192582bd26664276',
  messagingSenderId: '398834852035',
  projectId: 'fast-app-65ffc',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'Notification';
  const notificationOptions = {
    body: payload.notification?.body,
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});

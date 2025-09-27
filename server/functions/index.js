const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

// This is our new, secure, callable Cloud Function.
exports.deleteReceipt = functions.https.onCall(async (data, context) => {
  // Ensure the user calling this function is authenticated (e.g., the bookkeeper).
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const receiptId = data.receiptId;
  const receiptPath = data.receiptPath; // e.g., /users/USER_ID/receipts/RECEIPT_ID

  if (!receiptId || !receiptPath) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a `receiptId` and `receiptPath`."
    );
  }

  console.log(`Attempting to delete receipt: ${receiptPath}`);

  try {
    const docRef = db.doc(receiptPath);
    const doc = await docRef.get();
    
    if (!doc.exists) {
        console.log("Document not found, perhaps already deleted.");
        return { status: "success", message: "Document not found." };
    }

    const receiptData = doc.data();
    const imagePath = receiptData.imagePath;

    // 1. Delete the image from Cloud Storage, if it exists.
    if (imagePath && imagePath.startsWith("https://")) {
      const bucket = storage.bucket();
      const file = bucket.file(
        decodeURIComponent(imagePath.split("/o/")[1].split("?")[0])
      );
      await file.delete();
      console.log(`Successfully deleted image: ${imagePath}`);
    }

    // 2. Delete the document from Firestore.
    await docRef.delete();
    console.log(`Successfully deleted document: ${receiptPath}`);

    return { status: "success", message: "Receipt deleted successfully." };
  } catch (error) {
    console.error("Error deleting receipt:", error);
    throw new functions.https.HttpsError(
      "internal",
      "An error occurred while deleting the receipt."
    );
  }
});
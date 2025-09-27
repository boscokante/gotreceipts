// Your web app's Firebase configuration
const firebaseConfig = {
    apiKey: "AIzaSyC3-Fd50ofNs6MwtltxOSz_AAt66XmhICQ",
    authDomain: "gotreceipts-92365.firebaseapp.com",
    projectId: "gotreceipts-92365",
    storageBucket: "gotreceipts-92365.firebasestorage.app",
    messagingSenderId: "1027548827831",
    appId: "1:1027548827831:web:281d214fa1df40717ebd32"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

const auth = firebase.auth();
const db = firebase.firestore();
const functions = firebase.functions(); // Initialize the Functions service

// --- UI Elements ---
const loginView = document.getElementById('login-view');
const dashboardView = document.getElementById('dashboard-view');
const loginButton = document.getElementById('login-button');
const logoutButton = document.getElementById('logout-button');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const errorMessage = document.getElementById('error-message');
const receiptsListDiv = document.getElementById('receipts-list');

let receiptsListener = null;

// --- Event Listeners ---
loginButton.addEventListener('click', () => {
    const email = emailInput.value;
    const password = passwordInput.value;
    auth.signInWithEmailAndPassword(email, password).catch(error => {
        errorMessage.textContent = error.message;
    });
});

logoutButton.addEventListener('click', () => {
    auth.signOut();
});

// --- Auth State Observer ---
auth.onAuthStateChanged((user) => {
    if (user) {
        loginView.style.display = 'none';
        dashboardView.style.display = 'block';
        if (receiptsListener) receiptsListener();
        listenForCompanyReceipts("electrospit");
    } else {
        loginView.style.display = 'block';
        dashboardView.style.display = 'none';
        if (receiptsListener) receiptsListener();
        receiptsListDiv.innerHTML = "";
    }
});

// --- Firestore Data Fetching ---
function listenForCompanyReceipts(companyKey) {
    const query = db.collectionGroup('receipts')
                    .where("companyKey", "==", companyKey)
                    .orderBy("createdAt", "desc");

    receiptsListener = query.onSnapshot(snapshot => {
        if (snapshot.empty) {
            receiptsListDiv.innerHTML = "<p>No receipts found for this company.</p>";
            return;
        }
        
        let html = "<table><thead><tr><th>Date</th><th>Merchant</th><th>Amount</th><th>Memo</th><th>Image</th><th>Actions</th></tr></thead><tbody>";
        snapshot.forEach(doc => {
            const receipt = doc.data();
            const parsed = receipt.parsed || {};
            
            const date = receipt.createdAt.toDate().toLocaleDateString();
            const merchant = parsed.merchant || "N/A";
            const amount = parsed.amount ? `$${parsed.amount.toFixed(2)}` : "N/A";
            const memo = receipt.speech || "";
            const imageLink = receipt.imagePath ? `<a href="${receipt.imagePath}" target="_blank" rel="noopener noreferrer">View</a>` : "No Image";
            
            // This now includes the full document path in the data-path attribute.
            const deleteButton = `<button class="delete-button" data-path="${doc.ref.path}">Delete</button>`;
            
            html += `<tr><td>${date}</td><td>${merchant}</td><td>${amount}</td><td>${memo}</td><td>${imageLink}</td><td>${deleteButton}</td></tr>`;
        });
        html += "</tbody></table>";
        
        receiptsListDiv.innerHTML = html;
        
        // Add event listeners to all the new delete buttons.
        document.querySelectorAll('.delete-button').forEach(button => {
            button.addEventListener('click', handleDeleteClick);
        });
        
    }, error => {
        console.error("Error fetching receipts: ", error);
        receiptsListDiv.innerHTML = `<p class="error-message">Error loading receipts: ${error.message}. Check console for details.</p>`;
    });
}

// --- Delete Logic ---
function handleDeleteClick(event) {
    const receiptPath = event.target.dataset.path;
    const receiptId = receiptPath.split("/").pop();

    if (!confirm("Are you sure you want to delete this receipt? This action cannot be undone.")) {
        return;
    }
    
    // Get a reference to our Cloud Function.
    const deleteReceipt = functions.httpsCallable('deleteReceipt');
    
    // Call the function with the necessary data.
    deleteReceipt({ receiptId: receiptId, receiptPath: receiptPath })
        .then((result) => {
            console.log("Cloud Function result: ", result.data.message);
            // The real-time listener will automatically remove the row from the table.
        })
        .catch((error) => {
            console.error("Error calling deleteReceipt function: ", error);
            alert(`An error occurred: ${error.message}`);
        });
}
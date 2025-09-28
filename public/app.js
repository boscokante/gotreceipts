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
const Timestamp = firebase.firestore.Timestamp;
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

// Card management elements
const manageCardsButton = document.getElementById('manage-cards-button');
const cardModal = document.getElementById('card-modal');
const closeCardModal = document.getElementById('close-card-modal');
const lastFourInput = document.getElementById('last-four');
const entityInput = document.getElementById('entity');
const cardTypeInput = document.getElementById('card-type');
const bankInput = document.getElementById('bank');
const addCardButton = document.getElementById('add-card-button');
const cardErrorMessage = document.getElementById('card-error-message');
const cardsContainer = document.getElementById('cards-container');

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

// Card management event listeners
manageCardsButton.addEventListener('click', () => {
    cardModal.style.display = 'flex';
    loadCards();
});

closeCardModal.addEventListener('click', () => {
    cardModal.style.display = 'none';
});

addCardButton.addEventListener('click', addCard);

// Close modal when clicking outside
cardModal.addEventListener('click', (e) => {
    if (e.target === cardModal) {
        cardModal.style.display = 'none';
    }
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
        
        let html = "<table><thead><tr><th>Date</th><th>Merchant</th><th>Amount</th><th>Memo</th><th>Location</th><th>Card</th><th>Image</th><th>Actions</th></tr></thead><tbody>";
        snapshot.forEach(doc => {
            const receipt = doc.data();
            const parsed = receipt.parsed || {};
            const geo = receipt.geo || {};
            
            const date = receipt.createdAt.toDate().toLocaleDateString();
            const merchant = parsed.merchant || "N/A";
            const amount = parsed.amount ? `$${parsed.amount.toFixed(2)}` : "N/A";
            const memo = receipt.speech || "";
            
            // Location information - prioritize detailed address over coordinates
            let location = "N/A";
            if (parsed.locationName && parsed.locationName.trim() !== "") {
                location = parsed.locationName;
            } else if (geo.lat && geo.lng) {
                location = `📍 ${geo.lat.toFixed(6)}, ${geo.lng.toFixed(6)}`;
            }
            
            // Card information
            const cardInfo = receipt.lastFour ? `****${receipt.lastFour}` : "N/A";
            
            const imageLink = receipt.imagePath ? `<a href="${receipt.imagePath}" target="_blank" rel="noopener noreferrer">View</a>` : "No Image";
            
            // This now includes the full document path in the data-path attribute.
            const deleteButton = `<button class="delete-button" data-path="${doc.ref.path}">Delete</button>`;
            
            html += `<tr><td>${date}</td><td>${merchant}</td><td>${amount}</td><td>${memo}</td><td>${location}</td><td>${cardInfo}</td><td>${imageLink}</td><td>${deleteButton}</td></tr>`;
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

// --- Card Management Functions ---
function addCard() {
    const lastFour = lastFourInput.value.trim();
    const entity = entityInput.value.trim();
    const cardType = cardTypeInput.value.trim();
    const bank = bankInput.value.trim();
    
    if (!lastFour || !entity || !cardType || !bank) {
        cardErrorMessage.textContent = "All fields are required";
        return;
    }
    
    if (!/^\d{4}$/.test(lastFour)) {
        cardErrorMessage.textContent = "Last four must be exactly 4 digits";
        return;
    }
    
    cardErrorMessage.textContent = "";
    
    const cardData = {
        id: Date.now().toString(),
        lastFour: lastFour,
        entity: entity,
        cardType: cardType,
        bank: bank,
        active: true,
        createdAt: Timestamp.now()
    };
    
    const docRef = db.collection('userCards').doc('electrospit');
    
    docRef.get().then((doc) => {
        let cards = [];
        if (doc.exists) {
            cards = doc.data().cards || [];
            // Check duplicate
            if (cards.some(card => card.lastFour === lastFour)) {
                throw new Error("A card with this last four already exists");
            }
        }
        cards.push(cardData);
        return docRef.set({ cards: cards }, { merge: true });
    }).then(() => {
        lastFourInput.value = '';
        entityInput.value = '';
        cardTypeInput.value = '';
        bankInput.value = '';
        cardErrorMessage.textContent = '';
        loadCards();
    }).catch((error) => {
        cardErrorMessage.textContent = error.message;
    });
}

function loadCards() {
    const docRef = db.collection('userCards').doc('electrospit');
    
    docRef.get().then((doc) => {
        if (doc.exists) {
            const cards = doc.data().cards || [];
            displayCards(cards);
        } else {
            cardsContainer.innerHTML = '<p>No cards found. Add your first card above.</p>';
        }
    }).catch((error) => {
        console.error("Error loading cards: ", error);
        cardsContainer.innerHTML = '<p class="error-message">Error loading cards</p>';
    });
}

function displayCards(cards) {
    if (cards.length === 0) {
        cardsContainer.innerHTML = '<p>No cards found. Add your first card above.</p>';
        return;
    }
    
    let html = '';
    cards.forEach(card => {
        const statusClass = card.active ? '' : 'inactive';
        const statusText = card.active ? 'Active' : 'Inactive';
        
        html += `
            <div class="card-item">
                <div class="card-info">
                    ${card.lastFour}_${card.entity}_${card.cardType}_${card.bank}
                </div>
                <div class="card-actions">
                    <button class="toggle-button ${statusClass}" onclick="toggleCard('${card.id}', ${card.active})">
                        ${statusText}
                    </button>
                    <button class="delete-button" onclick="deleteCard('${card.id}')">
                        Delete
                    </button>
                </div>
            </div>
        `;
    });
    
    cardsContainer.innerHTML = html;
}

function toggleCard(cardId, currentStatus) {
    const docRef = db.collection('userCards').doc('electrospit');
    
    docRef.get().then((doc) => {
        const cards = (doc.exists ? doc.data().cards : []) || [];
        const cardIndex = cards.findIndex(card => card.id === cardId);
        if (cardIndex !== -1) {
            cards[cardIndex].active = !currentStatus;
            return docRef.set({ cards: cards }, { merge: true });
        }
    }).then(() => {
        loadCards();
    }).catch((error) => {
        console.error("Error toggling card: ", error);
        alert("Error updating card status");
    });
}

function deleteCard(cardId) {
    if (!confirm("Are you sure you want to delete this card?")) {
        return;
    }
    
    const docRef = db.collection('userCards').doc('electrospit');
    
    docRef.get().then((doc) => {
        const cards = (doc.exists ? doc.data().cards : []) || [];
        const filteredCards = cards.filter(card => card.id !== cardId);
        return docRef.set({ cards: filteredCards }, { merge: true });
    }).then(() => {
        loadCards();
    }).catch((error) => {
        console.error("Error deleting card: ", error);
        alert("Error deleting card");
    });
}
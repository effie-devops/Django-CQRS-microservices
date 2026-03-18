const API = {
  reader: '/api/reader',
  writer: '/api/writer'
};

const form = document.getElementById('book-form');
const formTitle = document.getElementById('form-title');
const bookIdInput = document.getElementById('book-id');
const titleInput = document.getElementById('title');
const authorInput = document.getElementById('author');
const submitBtn = document.getElementById('submit-btn');
const cancelBtn = document.getElementById('cancel-btn');
const message = document.getElementById('message');
const booksList = document.getElementById('books-list');
const loading = document.getElementById('loading');
const empty = document.getElementById('empty');

let descriptionInput;

function ensureDescriptionField() {
  if (!descriptionInput) {
    descriptionInput = document.createElement('input');
    descriptionInput.type = 'text';
    descriptionInput.id = 'description';
    descriptionInput.placeholder = 'Description';
    descriptionInput.required = true;
    authorInput.after(descriptionInput);
  }
}

ensureDescriptionField();

async function fetchBooks() {
  loading.hidden = false;
  empty.hidden = true;
  booksList.innerHTML = '';

  try {
    const res = await fetch(`${API.reader}/books/`);
    const books = await res.json();
    loading.hidden = true;

    if (!books.length) {
      empty.hidden = false;
      return;
    }

    books.forEach(book => {
      const card = document.createElement('div');
      card.className = 'book-card';
      card.innerHTML = `
        <div class="book-info">
          <h3>${esc(book.title)}</h3>
          <p>${esc(book.author)}</p>
          <p style="font-size:0.8rem;color:#9ca3af;margin-top:0.25rem">${esc(book.description || '')}</p>
        </div>
        <div class="book-actions">
          <button class="edit" onclick="editBook(${book.id}, '${esc(book.title)}', '${esc(book.author)}', '${esc(book.description || '')}')">Edit</button>
          <button class="delete" onclick="deleteBook(${book.id})">Delete</button>
        </div>`;
      booksList.appendChild(card);
    });
  } catch (err) {
    loading.hidden = true;
    showMessage('Failed to load books', 'error');
  }
}

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = bookIdInput.value;
  const body = {
    title: titleInput.value,
    author: authorInput.value,
    description: descriptionInput.value
  };

  try {
    const url = id
      ? `${API.writer}/books/${id}/update/`
      : `${API.writer}/books/create/`;
    const method = id ? 'PUT' : 'POST';

    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });

    if (!res.ok) throw new Error(await res.text());

    showMessage(id ? 'Book updated' : 'Book added', 'success');
    resetForm();
    fetchBooks();
  } catch (err) {
    showMessage('Failed to save book', 'error');
  }
});

window.editBook = function(id, title, author, description) {
  bookIdInput.value = id;
  titleInput.value = title;
  authorInput.value = author;
  descriptionInput.value = description;
  formTitle.textContent = 'Edit Book';
  submitBtn.textContent = 'Update Book';
  cancelBtn.hidden = false;
  titleInput.focus();
};

window.deleteBook = async function(id) {
  if (!confirm('Delete this book?')) return;
  try {
    const res = await fetch(`${API.writer}/books/${id}/delete/`, { method: 'DELETE' });
    if (!res.ok) throw new Error();
    showMessage('Book deleted', 'success');
    fetchBooks();
  } catch {
    showMessage('Failed to delete book', 'error');
  }
};

cancelBtn.addEventListener('click', resetForm);

function resetForm() {
  bookIdInput.value = '';
  form.reset();
  formTitle.textContent = 'Add a Book';
  submitBtn.textContent = 'Add Book';
  cancelBtn.hidden = true;
}

function showMessage(text, type) {
  message.textContent = text;
  message.className = type;
  message.hidden = false;
  setTimeout(() => { message.hidden = true; }, 3000);
}

function esc(str) {
  const d = document.createElement('div');
  d.textContent = str;
  return d.innerHTML.replace(/'/g, "\\'");
}

fetchBooks();

class UserCard extends HTMLElement {
  constructor() {
    // 1. Always call super() first to establish the prototype chain
    super();

    // 2. Attach an 'open' Shadow DOM root to the component
    // 'open' means the shadow root can be accessed via JavaScript externally
    this.attachShadow({ mode: 'open' });

    // 3. Get the template element from the document
    const template = document.getElementById('user-card-template');
    
    // 4. Clone the content of the template (deep copy)
    const templateContent = template.content.cloneNode(true);

    // 5. Append the cloned template to the shadow root
    this.shadowRoot.appendChild(templateContent);
  }

  // Lifecycle method called when the element is inserted into the DOM
  connectedCallback() {
    // Select elements inside the shadow DOM using this.shadowRoot
    const button = this.shadowRoot.querySelector('#toggle-btn');
    
    button.addEventListener('click', () => {
      if (button.textContent === 'Follow') {
        button.textContent = 'Following';
        button.style.background = '#28a745';
      } else {
        button.textContent = 'Follow';
        button.style.background = '#007bef';
      }
    });
  }
}

// Register the custom element with the browser
customElements.define('user-card', UserCard);

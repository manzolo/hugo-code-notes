// Simple search functionality
document.addEventListener('DOMContentLoaded', function() {
  const searchInput = document.getElementById('searchInput');
  const searchResults = document.getElementById('searchResults');
  const searchStats = document.getElementById('searchStats');
  const resultsCount = document.getElementById('resultsCount');
  const quickTags = document.getElementById('quickTags');
  const noResults = document.getElementById('noResults');
  const tagButtons = document.querySelectorAll('.tag-btn');
  
  let searchData = [];
  
  // Load search data
  fetch('/index.json')
    .then(response => response.json())
    .then(data => {
      searchData = data;
    })
    .catch(error => {
      console.error('Search data not found:', error);
    });

  // Search with debounce
  let searchTimeout;
  searchInput.addEventListener('input', function() {
    clearTimeout(searchTimeout);
    const query = this.value.trim();
    
    if (query.length > 0) {
      searchTimeout = setTimeout(() => performSearch(query), 300);
    } else {
      showDefault();
    }
  });

  // Tag buttons
  tagButtons.forEach(button => {
    button.addEventListener('click', function() {
      const query = this.dataset.query;
      searchInput.value = query;
      performSearch(query);
    });
  });

  // Perform search
  function performSearch(query) {
    if (!searchData.length) return;
    
    const results = searchData.filter(item => {
      const searchText = (item.title + ' ' + item.content + ' ' + (item.tags || []).join(' ')).toLowerCase();
      return searchText.includes(query.toLowerCase());
    });

    displayResults(results, query);
  }

  // Display results
  function displayResults(results, query) {
    quickTags.style.display = 'none';
    
    if (results.length === 0) {
      searchResults.style.display = 'none';
      searchStats.style.display = 'none';
      noResults.style.display = 'block';
      return;
    }

    // Show stats
    searchStats.style.display = 'block';
    resultsCount.textContent = results.length + ' result' + (results.length !== 1 ? 's' : '');
    
    // Show results
    searchResults.style.display = 'block';
    noResults.style.display = 'none';
    
    searchResults.innerHTML = results.map(result => `
      <li class="search-result">
        <h3 class="result-title">
          <a href="${result.permalink}">${highlightText(result.title, query)}</a>
        </h3>
        <p class="result-summary">
          ${highlightText(truncateText(result.summary || result.content || '', 150), query)}
        </p>
        <div class="result-meta">
          ${result.date ? `<time>${formatDate(result.date)}</time>` : ''}
          ${result.categories && result.categories[0] ? `<span class="result-category">${result.categories[0]}</span>` : ''}
        </div>
      </li>
    `).join('');
  }

  // Show default state
  function showDefault() {
    searchResults.style.display = 'none';
    searchStats.style.display = 'none';
    noResults.style.display = 'none';
    quickTags.style.display = 'block';
  }

  // Helper functions
  function highlightText(text, query) {
    if (!query || !text) return text;
    const regex = new RegExp('(' + escapeRegExp(query) + ')', 'gi');
    return text.replace(regex, '<mark>$1</mark>');
  }

  function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function truncateText(text, maxLength) {
    if (!text || text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }

  function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  }
});
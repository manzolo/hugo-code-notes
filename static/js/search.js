// Enhanced search functionality for comprehensive content
document.addEventListener('DOMContentLoaded', function() {
  const searchInput = document.getElementById('searchInput');
  const searchResults = document.getElementById('searchResults');
  const searchStats = document.getElementById('searchStats');
  const resultsCount = document.getElementById('resultsCount');
  const quickTags = document.getElementById('quickTags');
  const noResults = document.getElementById('noResults');
  const tagButtons = document.querySelectorAll('.tag-btn');
  
  let searchData = [];
  
  // Check if all required elements exist
  if (!searchInput || !searchResults || !searchStats || !resultsCount || !quickTags || !noResults) {
    console.error('Missing required DOM elements for search functionality');
    return;
  }
  
  // Load search data
  fetch('/index.json')
    .then(response => response.json())
    .then(data => {
      searchData = data;
      console.log(`Loaded ${searchData.length} searchable items`);
      
      // Log content types for debugging
      const types = {};
      searchData.forEach(item => {
        types[item.type] = (types[item.type] || 0) + 1;
      });
      console.log('Search index contains:', types);
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

  // Enhanced search function
  function performSearch(query) {
    if (!searchData.length) return;
    
    const queryLower = query.toLowerCase();
    const results = [];
    
    searchData.forEach(item => {
      let score = 0;
      let matches = [];
      
      // Search in title (highest priority)
      if (item.title && item.title.toLowerCase().includes(queryLower)) {
        score += 10;
        matches.push('title');
      }
      
      // Search in summary
      if (item.summary && item.summary.toLowerCase().includes(queryLower)) {
        score += 5;
        matches.push('summary');
      }
      
      // Search in content
      if (item.content && item.content.toLowerCase().includes(queryLower)) {
        score += 3;
        matches.push('content');
      }
      
      // Search in categories
      if (item.categories && item.categories.length > 0) {
        const categoryMatch = item.categories.some(cat => 
          cat.toLowerCase().includes(queryLower)
        );
        if (categoryMatch) {
          score += 7;
          matches.push('category');
        }
      }
      
      // Search in tags
      if (item.tags && item.tags.length > 0) {
        const tagMatch = item.tags.some(tag => 
          tag.toLowerCase().includes(queryLower)
        );
        if (tagMatch) {
          score += 6;
          matches.push('tag');
        }
      }
      
      // Search in section
      if (item.section && item.section.toLowerCase().includes(queryLower)) {
        score += 4;
        matches.push('section');
      }
      
      if (score > 0) {
        results.push({
          ...item,
          searchScore: score,
          matchedFields: matches
        });
      }
    });
    
    // Sort by score (descending) and then by type priority
    results.sort((a, b) => {
      if (a.searchScore !== b.searchScore) {
        return b.searchScore - a.searchScore;
      }
      
      // Type priority: posts > pages > categories > tags
      const typePriority = {
        'post': 4,
        'page': 3,
        'category': 2,
        'tag': 1
      };
      
      return (typePriority[b.type] || 0) - (typePriority[a.type] || 0);
    });

    displayResults(results, query);
  }

  // Enhanced display function
  function displayResults(results, query) {
    if (quickTags) {
      quickTags.style.display = 'none';
    }
    
    if (results.length === 0) {
      if (searchResults) searchResults.style.display = 'none';
      if (searchStats) searchStats.style.display = 'none';
      if (noResults) noResults.style.display = 'block';
      return;
    }

    // Show stats with breakdown
    if (searchStats) {
      searchStats.style.display = 'block';
      const typeBreakdown = {};
      results.forEach(result => {
        typeBreakdown[result.type] = (typeBreakdown[result.type] || 0) + 1;
      });
      
      const breakdownText = Object.entries(typeBreakdown)
        .map(([type, count]) => `${count} ${type}${count !== 1 ? 's' : ''}`)
        .join(', ');
      
      if (resultsCount) {
        resultsCount.textContent = `${results.length} result${results.length !== 1 ? 's' : ''} (${breakdownText})`;
      }
    }
    
    // Show results
    if (searchResults) {
      searchResults.style.display = 'block';
      searchResults.innerHTML = results.map(result => {
        const typeIcon = getTypeIcon(result.type);
        const typeLabel = getTypeLabel(result.type);
        
        return `
          <li class="search-result" data-type="${result.type}">
            <h3 class="result-title">
              <a href="${result.permalink}">
                <span class="result-type-icon">${typeIcon}</span>
                ${highlightText(result.title, query)}
                <span class="result-type-label">${typeLabel}</span>
              </a>
            </h3>
            <p class="result-summary">
              ${highlightText(truncateText(result.summary || '', 150), query)}
            </p>
            <div class="result-meta">
              ${result.date ? `<time>${formatDate(result.date)}</time>` : ''}
              ${result.postCount ? `<span class="post-count">${result.postCount} posts</span>` : ''}
              ${result.readingTime ? `<span class="reading-time">${result.readingTime} min read</span>` : ''}
              ${result.categories && result.categories.length > 0 ? 
                `<span class="result-categories">${result.categories.slice(0, 2).join(', ')}</span>` : ''}
              ${result.matchedFields ? 
                `<span class="matched-fields">Found in: ${result.matchedFields.join(', ')}</span>` : ''}
            </div>
          </li>
        `;
      }).join('');
    }
    
    if (noResults) {
      noResults.style.display = 'none';
    }
  }

  // Helper functions
  function getTypeIcon(type) {
    const icons = {
      'post': '📄',
      'page': '📝',
      'category': '📁',
      'tag': '🏷️'
    };
    return icons[type] || '📄';
  }
  
  function getTypeLabel(type) {
    const labels = {
      'post': 'Post',
      'page': 'Page',
      'category': 'Category',
      'tag': 'Tag'
    };
    return labels[type] || 'Content';
  }

  // Show default state
  function showDefault() {
    if (searchResults) searchResults.style.display = 'none';
    if (searchStats) searchStats.style.display = 'none';
    if (noResults) noResults.style.display = 'none';
    if (quickTags) quickTags.style.display = 'block';
  }

  // Existing helper functions
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
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  }
});
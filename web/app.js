const $ = (id) => document.getElementById(id);
const messages = $('messages');
const endpoint = $('endpoint');
const state = $('state');

function append(role, text) {
  const node = document.createElement('div');
  node.className = `message ${role}`;
  node.textContent = text;
  messages.appendChild(node);
  messages.scrollTop = messages.scrollHeight;
}

async function request(path, options = {}) {
  const base = endpoint.value.replace(/\/$/, '');
  const response = await fetch(base + path, options);
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || response.statusText);
  return data;
}

$('health').addEventListener('click', async () => {
  try {
    const data = await request('/health');
    state.textContent = `ready • ${data.state}`;
  } catch (error) {
    state.textContent = 'offline';
    append('system', `Health check failed: ${error.message}`);
  }
});

$('chat').addEventListener('submit', async (event) => {
  event.preventDefault();
  const input = $('input');
  const content = input.value.trim();
  if (!content) return;
  input.value = '';
  append('user', content);
  try {
    const data = await request('/v1/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({messages: [{role: 'user', content}]})
    });
    append('assistant', data.content || data.error || 'No response');
  } catch (error) {
    append('system', `Request failed: ${error.message}`);
  }
});

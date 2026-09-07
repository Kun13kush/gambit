const API_URL =
  import.meta.env.VITE_API_URL ||
  "http://localhost:8000";

async function request(endpoint) {
  const response = await fetch(
    `${API_URL}${endpoint}`
  );

  if (!response.ok) {
    throw new Error(
      `API request failed: ${response.status}`
    );
  }

  return response.json();
}

export function getHealth() {
  return request("/health");
}

export function getServices() {
  return request("/api/services");
}

export function getDeployments() {
  return request("/api/deployments");
}
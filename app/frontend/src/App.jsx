function App() {
  return (
    <div className="app">
      <header className="header">
        <div className="brand">
          <div className="logo">G</div>

          <div>
            <h1>Gambit</h1>
            <p>AWS Platform</p>
          </div>
        </div>

        <div className="status">
          <span className="status-dot"></span>
          Platform Online
        </div>
      </header>

      <main className="main">
        <section className="hero">
          <div>
            <p className="eyebrow">PRODUCTION PLATFORM</p>

            <h2>
              Cloud infrastructure
              <br />
              built for reliability.
            </h2>

            <p className="description">
              Gambit provides a centralized view of deployments,
              infrastructure health, and application operations.
            </p>

            <button
              className="button"
              onClick={() => alert('Gambit frontend is working!')}
            >
              Test Platform
            </button>
          </div>

          <div className="architecture">
            <div className="architecture-title">
              Infrastructure Status
            </div>

            <div className="architecture-grid">
              <Status name="AWS" status="Operational" />
              <Status name="Kubernetes" status="Operational" />
              <Status name="CI/CD" status="Operational" />
              <Status name="Monitoring" status="Operational" />
            </div>
          </div>
        </section>

        <section className="metrics">
          <Metric label="Deployments" value="24" />
          <Metric label="Success Rate" value="99.2%" />
          <Metric label="Services" value="12" />
          <Metric label="Incidents" value="0" />
        </section>

        <section className="panel">
          <div className="panel-header">
            <div>
              <p className="eyebrow">DEPLOYMENTS</p>
              <h3>Recent Deployments</h3>
            </div>

            <span className="live">LIVE</span>
          </div>

          <div className="deployment">
            <div>
              <strong>frontend</strong>
              <span>main · production</span>
            </div>

            <div className="success">Successful</div>

            <time>2 min ago</time>
          </div>

          <div className="deployment">
            <div>
              <strong>api</strong>
              <span>main · production</span>
            </div>

            <div className="success">Successful</div>

            <time>18 min ago</time>
          </div>

          <div className="deployment">
            <div>
              <strong>worker</strong>
              <span>main · production</span>
            </div>

            <div className="success">Successful</div>

            <time>31 min ago</time>
          </div>
        </section>
      </main>

      <footer>
        Gambit Platform · AWS · Kubernetes · CI/CD
      </footer>
    </div>
  )
}

function Status({ name, status }) {
  return (
    <div className="status-card">
      <div className="service-name">{name}</div>

      <div className="service-status">
        <span className="status-dot"></span>
        {status}
      </div>
    </div>
  )
}

function Metric({ label, value }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

export default App
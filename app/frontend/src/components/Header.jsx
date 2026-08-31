function Header() {
  return (
    <header className="header">
      <div>
        <h1>Production AWS Platform</h1>
        <p>Cloud Operations Dashboard</p>
      </div>

      <div className="system-status">
        <span className="status-dot" />
        Operational
      </div>
    </header>
  );
}

export default Header;
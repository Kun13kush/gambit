function Sidebar() {
  const items = [
    "Dashboard",
    "Services",
    "Deployments",
    "Infrastructure",
    "Monitoring",
    "Security",
  ];

  return (
    <aside className="sidebar">
      <div className="brand">
        OPS
      </div>

      <nav>
        {items.map((item, index) => (
          <div
            key={item}
            className={`nav-item ${
              index === 0 ? "active" : ""
            }`}
          >
            {item}
          </div>
        ))}
      </nav>
    </aside>
  );
}

export default Sidebar;
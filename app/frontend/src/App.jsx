import PropTypes from "prop-types";

function App() {
  // your existing App JSX
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
  );
}

Status.propTypes = {
  name: PropTypes.string.isRequired,
  status: PropTypes.string.isRequired,
};

function Metric({ label, value }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

Metric.propTypes = {
  label: PropTypes.string.isRequired,
  value: PropTypes.string.isRequired,
};

export default App;
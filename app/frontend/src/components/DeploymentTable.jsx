import PropTypes from "prop-types";

function DeploymentTable({ deployments }) {
  return (
    <div className="panel">
      <div className="panel-header">
        <h2>Recent Deployments</h2>
      </div>

      <div className="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>Service</th>
              <th>Version</th>
              <th>Status</th>
              <th>Deployed</th>
            </tr>
          </thead>

          <tbody>
            {deployments.map((deployment) => (
              <tr key={deployment.id}>
                <td>{deployment.service}</td>

                <td>{deployment.version}</td>

                <td>
                  <span
                    className={`badge ${
                      deployment.status === "successful"
                        ? "healthy"
                        : "warning"
                    }`}
                  >
                    {deployment.status}
                  </span>
                </td>

                <td>
                  {new Date(deployment.deployed_at).toLocaleString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

DeploymentTable.propTypes = {
  deployments: PropTypes.array.isRequired,
};

export default DeploymentTable;
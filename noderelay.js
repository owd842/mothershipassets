const jayson = require('jayson');

// Create the HTTP client pointing to your JSON-RPC server URL
const client = jayson.Client.http({
  host: 'localhost',
  port: 3000,
  path: '/jsonrpc' // Default JSON-RPC endpoint
});

// Polling interval in milliseconds (e.g., every 2 seconds)
const POLLING_INTERVAL = 2000; 

const pollServer = () => {
  // 'add' is the JSON-RPC method, [1, 2] are the parameters
  client.request('add', [1, 2], (err, response) => {
    if (err) {
      console.error('Request failed:', err);
      return;
    }
    
    if (response.error) {
      console.error('RPC Error:', response.error);
    } else {
      console.log('Result:', response.result);
    }
  });
};

// Start the polling loop
const intervalId = setInterval(pollServer, POLLING_INTERVAL);


debugger;

const jsforce = require('jsforce');

// Configure your Salesforce credentials
const SF_LOGIN_URL = 'https://login.salesforce.com'; // or your custom domain
const SF_USERNAME = 'your-email@example.com';
const SF_PASSWORD = 'your-password-and-security-token';

const conn = new jsforce.Connection({
  loginUrl: SF_LOGIN_URL
});

conn.login(SF_USERNAME, SF_PASSWORD, (err, userInfo) => {
  if (err) {
    return console.error('Salesforce login failed: ', err);
  }
  console.log('Connected to Salesforce as: ' + userInfo.id);

  // Define the platform event channel (e.g., Custom_Event__e)
  const channel = '/event/Custom_Event__e';

  console.log(`Subscribing to channel: ${channel}`);

  // Subscribe to the streaming topic
  const subscription = conn.streaming.topic(channel).subscribe((message) => {
    console.log('Platform Event received:', JSON.stringify(message, null, 2));
  });

  // Optional: Handle subscription success/error
  console.log('Listening for events...');
});

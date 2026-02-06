module.exports = async (context) => {
  const { electronPlatformName, appOutDir } = context;
  if (electronPlatformName !== 'darwin') return;

  const required = [
    'APPLE_ID',
    'APPLE_APP_SPECIFIC_PASSWORD',
    'APPLE_TEAM_ID'
  ];

  const missing = required.filter((k) => !process.env[k]);
  if (missing.length > 0) {
    console.log('Skipping notarization; missing env vars:', missing.join(', '));
    return;
  }

  console.log('Notarization env vars present. App output at:', appOutDir);
  console.log('Signing/notarization execution intentionally left to release pipeline.');
};

const Escrow = artifacts.require('Escrow');

module.exports = async function (deployer) {
  await deployer.deploy(
    Escrow,
    '0x006D6F5912F260383ca1621D0d424Cd0e53824Be',
    '0x764635f0CAfE21315fd5bdB247965C2e442a3Bb7',
    '20'
  );
};

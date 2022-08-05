const TestToken = artifacts.require('TestToken');
const CountdownButton = artifacts.require('CountdownButton');
const currentTime = parseInt(new Date().getTime() / 1000);

module.exports = async function (deployer) {
  //deploy token
  await deployer.deploy(
    TestToken,
    '0xc30004803f5dc1f6ad15193a197fd1fbd0d471d1'
  );
  const token = await TestToken.deployed();
  //deploy CountdownButton contract
  await deployer.deploy(
    CountdownButton,
    '0xbB729f824D6C8Ca59106dcE008265A74b785aa99',
    token.address,
    36000,
    currentTime
  );
};

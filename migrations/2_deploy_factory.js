const Migrations = artifacts.require("SyCrowBarterFactory");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};

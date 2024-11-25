const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { upgrades } = require("hardhat");

const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
const ONE_GWEI = 1_000_000_000;

describe("GMOVE", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    const [owner] = await ethers.getSigners();
    const mockToken = await ethers.getContractFactory("ERC20Mock");
    const TOKEN = await mockToken.deploy("Mock MOVE", "MOVE", owner.address, BigInt(1_000_000_000) * BigInt(10) ** BigInt(18));
    await TOKEN.waitForDeployment();
    const gMOVE = await ethers.getContractFactory("GMOVE");
    const GMOVE = await upgrades.deployProxy(gMOVE, [await TOKEN.getAddress(), owner.address], {});
    await GMOVE.waitForDeployment();
    await TOKEN.approve(await GMOVE.getAddress(), BigInt(1_000_000_000) * BigInt(10) ** BigInt(18));
    return { GMOVE, TOKEN, owner };
  }

  describe("Deployment", function () {
    it("Current exchange rate is 1e18", async function () {
      const { GMOVE, TOKEN } = await loadFixture(deployFixture);
      expect(await GMOVE.exchangeRate()).to.equal(BigInt(1) * BigInt(10) ** BigInt(18));
    });
    it("set APY to 5%", async function () {
      const { GMOVE, TOKEN } = await loadFixture(deployFixture);
      await GMOVE.setInterestRate(500);
      expect(await GMOVE.interestRate()).to.equal(500);
    });

    it("user can deposit", async function () {
      const { GMOVE, TOKEN } = await loadFixture(deployFixture);
      await GMOVE.deposit(BigInt(100) * BigInt(10) ** BigInt(18));
    });

    it("time pass", async function () {
      const { GMOVE, TOKEN, owner } = await loadFixture(deployFixture);

      await GMOVE.setInterestRate(700);
      expect(await GMOVE.interestRate()).to.equal(700);
      await GMOVE.deposit(BigInt(100) * BigInt(10) ** BigInt(18));
      await time.increase(ONE_YEAR_IN_SECS * 3);
      const result = await GMOVE.getMOVE(BigInt(100) * BigInt(10) ** BigInt(18))
      const result2 = await GMOVE.exchangeRate();
      const result3 = await GMOVE.currentExchangeRate();
      console.log(result, result2, result3);
    });


  });
});

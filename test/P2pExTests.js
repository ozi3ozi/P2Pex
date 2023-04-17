// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
const { expect } = require("chai");

// We use `loadFixture` to share common setups (or fixtures) between tests.
// Using this simplifies your tests and makes them run faster, by taking
// advantage of Hardhat Network's snapshot functionality.
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");

//String errors returned by contract functions
const DOESNT_EXIST = "Provider doesn't exist";
const ALREADY_EXISTS = "Provider already exists";
const MAX_REACHED = "Max allowed reached";

//properties names for provider
const myAddress = "myAddress";
const isAvailable = "isAvailable";
const autoCompleteTimeLimit = "autoCompleteTimeLimit";
const paymtMthds = "paymtMthds";
const currTradedTokens = "currTradedTokens";

//Constants in P2pEx
const MAX_PAYMT_MTHDS = 32;

// `describe` is a Mocha function that allows you to organize your tests.
// Having your tests organized makes debugging them easier. All Mocha
// functions are available in the global scope.
describe("P2pEx contract", function () {
  // We define a fixture to reuse the same setup in every test. We use
  // loadFixture to run this setup once, snapshot that state, and reset Hardhat
  // Network to that snapshot in every test.
  async function deployP2pExFixture() {
    // Get the ContractFactory and Signers here.
    const P2pEx = await ethers.getContractFactory("P2pEx");
    const [p2pExOwner, tstOwner, addr1, addr2] = await ethers.getSigners();

    const p2pExContract = await P2pEx.deploy();
    await p2pExContract.deployed();

    //We deploy ERC20 test token(TST) to help with testing P2pEx
    const TestToken = await ethers.getContractFactory("TestToken", tstOwner);
    const tstTokenContract = await TestToken.deploy();
    await tstTokenContract.deployed()

    // Fixtures can return anything you consider useful for your tests
    return { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 };
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    // `it` is another Mocha function. This is the one you use to define each
    // of your tests. It receives the test name, and a callback function.
    //
    // If the callback function is async, Mocha will `await` it.
    it("Should set the address deploying the contract as owner", async function () {
      // We use loadFixture to setup our environment, and then assert that
      // things went well
      const { p2pExContract, p2pExOwner } = await loadFixture(deployP2pExFixture);
      expect(await p2pExContract.owner()).to.equal(p2pExOwner.address);
    });

    it("Should give the address deploying Test token the full minted supply: 1000", async function () {
        const {tstTokenContract, tstOwner} = await loadFixture(deployP2pExFixture);
        console.log("Total supply: %d", await tstTokenContract.totalSupply());
        expect(await tstTokenContract.balanceOf(tstOwner.address)).to.equal(1000);
    })
  });
  
  async function seedOtherWallets(tokenContract, from, amount, to1, to2) {
    // const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1 } = await loadFixture(deployP2pExFixture);
    //Transfers from tstOwner to p2pExOwner and addr1
    await tokenContract.connect(from).transfer(to1.address, amount);
    await tokenContract.connect(from).transfer(to2.address, amount);
  }

  async function addProviders(p2pExContract, pr1, pr2, pr3) {
    await p2pExContract.connect(pr1).addProvider();
    await p2pExContract.connect(pr2).addProvider();
    await p2pExContract.connect(pr3).addProvider();
  }

  //We make deposits in p2pEx contract
  async function approveAndDepositInP2pEx(p2pExContract, tokenContract, amount, from) {
    await tokenContract.connect(from).approve(p2pExContract.address, amount);
    await p2pExContract.connect(from).depositToTrade(tokenContract.address, amount);
  }

  //Fixture to deploy P2pEx, seed the wallets, and deposit in P2pEx contract
  async function deployAndDepositInP2pEx() {
    const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
    await seedOtherWallets(tstTokenContract, tstOwner, 300, p2pExOwner, addr1);
    await addProviders(p2pExContract, p2pExOwner, tstOwner, addr1);
    await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 100, tstOwner);
    await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 200, p2pExOwner);
    await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 200, addr1);

    return { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 };
  }

  describe("Providers CRUD functions", function () {
    describe("addProvider()", async function () {
      it("Should not add existing provider", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await p2pExContract.connect(tstOwner).addProvider();
        await expect(p2pExContract.connect(tstOwner).addProvider()).to.be.revertedWith(ALREADY_EXISTS);
      });

      it("Should add new provider to providers mapping", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        expect(await p2pExContract.getAllProviders()).to.have.lengthOf(0);
        await p2pExContract.connect(tstOwner).addProvider();
        expect(await p2pExContract.getAllProviders()).to.have.lengthOf(1);
      });

      it("Should always set provider.myAddress to msg.sender", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await p2pExContract.connect(tstOwner).addProvider();
        expect(await p2pExContract.getProvider(tstOwner.address)).to.have.property(myAddress, tstOwner.address);
      });

      it("Should always set provider.autoCompleteTimeLimit to 4 hours", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await p2pExContract.connect(tstOwner).addProvider();
        expect((await p2pExContract.getProvider(tstOwner.address)).autoCompleteTimeLimit.eq(60*60*4)).to.equal(true);//4 hours in seconds
      });

      it("Should increase registeredProvidersCount", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        expect(await p2pExContract.getProvidersCount()).to.equal(0);
        await p2pExContract.connect(tstOwner).addProvider();
        expect(await p2pExContract.getProvidersCount()).to.equal(1);
      });
    });

    describe("addProvider()", async function () {
      it("Deleting revert if provider matching msg.sender is not found", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await expect(p2pExContract.connect(tstOwner).deleteProvider()).to.be.revertedWith(DOESNT_EXIST);
      });

      it("If found. Should delete provider that matches msg.sender from providers mapping", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await p2pExContract.connect(tstOwner).addProvider();
        await p2pExContract.connect(tstOwner).deleteProvider();
        expect((await p2pExContract.getProvider(tstOwner.address)).myAddress).to.not.be.equal(tstOwner.address);
      });

      it("Should decrease registeredProvidersCount", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await p2pExContract.connect(tstOwner).addProvider();
        await p2pExContract.connect(tstOwner).deleteProvider();
        expect(await p2pExContract.getProvidersCount()).to.equal(0);
      });
    });

    describe("addPaymtMthd()", async function () {
      const mockPymtMthd = "payment method**currencies accepted**transfer details";
      it("Should revert if provider matching msg.sender is not found", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await expect(p2pExContract.connect(tstOwner).addPaymtMthd(mockPymtMthd)).to.be.revertedWith(DOESNT_EXIST);
      });

      it("Should revert if max payment methods allowed reached", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await p2pExContract.connect(tstOwner).addProvider();
        for (let i = 0; i < MAX_PAYMT_MTHDS; i++) {
          await p2pExContract.connect(tstOwner).addPaymtMthd(mockPymtMthd);
        }
        await expect(p2pExContract.connect(tstOwner).addPaymtMthd(mockPymtMthd)).to.be.revertedWith(MAX_REACHED);
      });

      it("Should increase paymtMethods length.", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        
        await p2pExContract.connect(tstOwner).addProvider();
        await p2pExContract.connect(tstOwner).addPaymtMthd(mockPymtMthd);
        await p2pExContract.connect(tstOwner).addPaymtMthd(mockPymtMthd);
        expect((await p2pExContract.getProvider(tstOwner.address)).paymtMthds).to.have.lengthOf(2);
      });

      it("param _paymtMthd should match regex.", async function () {
        
      });
    });

    describe("<bool isAvailable> CRUD", function () {
      it("Should always return provider <bool isAvailable> as false when provider added for the first time", async function() {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);

        expect(await p2pExContract.getAllProviders()).to.have.lengthOf(0);
        
        await seedOtherWallets(tstTokenContract, tstOwner, 300, p2pExOwner, addr1);
        await addProviders(p2pExContract, p2pExOwner, tstOwner, addr1);
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 100, tstOwner);
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 200, p2pExOwner);
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 200, addr1);

        expect(await p2pExContract.getAvailability(tstOwner.address)).to.equal(false);
        expect(await p2pExContract.getAvailability(p2pExOwner.address)).to.equal(false);
        expect(await p2pExContract.getAvailability(addr1.address)).to.equal(false);

        expect(await p2pExContract.getAllProviders()).to.have.lengthOf(3);
        expect(await p2pExContract.getAvailableProviders()).to.have.lengthOf(0);
        expect(await p2pExContract.getUnavailableProviders()).to.have.lengthOf(3);
      });
      
      it("Provider should be able to update his <isAvailable> property", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployAndDepositInP2pEx);

        await p2pExContract.connect(addr1).becomeAvailable();
        expect(await p2pExContract.getAvailability(addr1.address)).to.equal(true);
        await p2pExContract.connect(addr1).becomeUnavailable();
        expect(await p2pExContract.getAvailability(addr1.address)).to.equal(false);
      });
      
      it("update availability should revert with 'Provider doesn't exist' if address is not a provider", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);
        //addr2 is not a provider
        await expect(p2pExContract.connect(addr2).becomeAvailable()).to.be.revertedWith(DOESNT_EXIST);
      });

      it("Should becomeAvailable() only if provider has at least one deposit in <mapping tradeableAmountByTokenByProvider>", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1, addr2 } = await loadFixture(deployP2pExFixture);

        await p2pExContract.connect(tstOwner).addProvider();
        await p2pExContract.connect(tstOwner).becomeAvailable();
        expect(await p2pExContract.getAvailability(tstOwner.address)).to.equal(false);

        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 300, tstOwner);
        await p2pExContract.connect(tstOwner).becomeAvailable();
        expect(await p2pExContract.getAvailability(tstOwner.address)).to.equal(true);
      });
    });

    describe("When can a provider trade. canTrade(_providerAddr)", async function () {
      it("Should revert with 'No balance to trade' if provider has no deposits in <mapping tradeableAmountByTokenByProvider>"), async function () {
        
      };

      it("Should becomeAvailable() if provider has at least one deposit in <mapping tradeableAmountByTokenByProvider>"), async function () {
        
      };
    });
  })

  describe("Deposit to p2pExContract logic. depositToTrade(_token, _tradeAmount)", function () {
    it("Should be a provider to deposit to trade.", async function() {
      const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1 } = await loadFixture(deployP2pExFixture);
      await seedOtherWallets(tstTokenContract, tstOwner, 300, p2pExOwner, addr1);

      expect(await p2pExContract.getProvidersCount()).to.equal(0);

      await tstTokenContract.connect(tstOwner).approve(p2pExContract.address, 100);
      await expect(p2pExContract.connect(tstOwner).depositToTrade(tstTokenContract.address, 100)).to.be.revertedWith(DOESNT_EXIST);

      await p2pExContract.connect(tstOwner).addProvider();
      await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 100, tstOwner);
      expect(await p2pExContract.getProvidersCount()).to.equal(1);
      expect(await p2pExContract.getProvider(tstOwner.address)).to.have.property(myAddress, tstOwner.address);

      await tstTokenContract.connect(p2pExOwner).approve(p2pExContract.address, 100);
      await expect(p2pExContract.connect(p2pExOwner).depositToTrade(tstTokenContract.address, 100)).to.be.revertedWith(DOESNT_EXIST);

      await p2pExContract.connect(p2pExOwner).addProvider();
      await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 200, p2pExOwner);
      expect(await p2pExContract.getProvidersCount()).to.equal(2);
      expect(await p2pExContract.getProvider(p2pExOwner.address)).to.have.property(myAddress, p2pExOwner.address);
    });

    it("tstOwner, p2pExOwner, and addr1 deposit 100, 150 and 200 TST respectively in p2pEx", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1 } = await loadFixture(deployP2pExFixture);
        await seedOtherWallets(tstTokenContract, tstOwner, 300, p2pExOwner, addr1);
        await addProviders(p2pExContract, tstOwner, p2pExOwner, addr1);
        
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 100, tstOwner);
        console.log("balance tstOwner: %d", await tstTokenContract.balanceOf(tstOwner.address));
        expect(await p2pExContract.getTradeableAmountByTokenByProvider(tstOwner.address, tstTokenContract.address)).to.equal(100);

        //Test for p2pExOwner
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 150, p2pExOwner);
        expect(await p2pExContract.getTradeableAmountByTokenByProvider(p2pExOwner.address, tstTokenContract.address)).to.equal(150);

        //Test for addr1
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 200, addr1);
        expect(await p2pExContract.getTradeableAmountByTokenByProvider(addr1.address, tstTokenContract.address)).to.equal(200);

    });

    it("Balance of p2pExContract should equal total deposits from wallets", async function () {
        const { p2pExContract, tstTokenContract, p2pExOwner, tstOwner, addr1 } = await loadFixture(deployP2pExFixture);
        totalDeposits = 0;
        // tstOwner transfers 300 TST to p2pExOwner and addr1 
        await seedOtherWallets(tstTokenContract, tstOwner, 300, p2pExOwner, addr1);
        await addProviders(p2pExContract, tstOwner, p2pExOwner, addr1);

        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 100, tstOwner);
        totalDeposits += 100;
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 150, p2pExOwner);
        totalDeposits += 150;
        await approveAndDepositInP2pEx(p2pExContract, tstTokenContract, 200, addr1);
        totalDeposits += 200;
        
        expect(await p2pExContract.balanceOf(tstTokenContract.address)).to.equal(totalDeposits);
    });
  });

});
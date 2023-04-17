// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
// import "remix_tests.sol"; // this import is automatically injected by Remix.
// import "hardhat/console.sol";
import "../contracts/P2pEx.sol";

contract DripP2PTest {
    DripP2P dripP2P;
    IERC20 erc20;

    function beforeEach() public {
        dripP2P = new DripP2P();
        dripP2P.addProvider();
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////PROVIDER PROPERTIES AND CRUD FUNCTIONS///////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    uint8 private maxPaymtMethods = 32;
    uint8 private maxTimeLimit = 4;

    function getAllProvidersTest() public {
        Assert.equal(dripP2P.getAllProviders().length, 1, "Total provider should be 2");
    }

    function getAvailableProvidersTest() public {
        Assert.equal(dripP2P.getAvailableProviders().length, 0, "Providers available should be 0");
    }

    function getUnavailableProvidersTest() public {
        Assert.equal(dripP2P.getUnavailableProviders().length, 1, "Providers available should be 2");
    }

    function onlyAddUniqueProvidersTest() public {
        Assert.equal(dripP2P.getAllProviders().length, 1, "Providers available should be 1");
    }

    function updateProviderTest() public {
        Assert.equal(dripP2P.getAllProviders()[0].isAvailable, false, "Provider should be unavailable");
        dripP2P.updateProvider(true, maxTimeLimit, new string[](maxPaymtMethods));
        Assert.equal(dripP2P.getAllProviders()[0].isAvailable, true, "Providers should be available");
    }

    function deleteProviderTest() public {
        Assert.equal(dripP2P.getAllProviders().length, 1, "Provider should be unavailable");
        dripP2P.deleteProvider();
        Assert.equal(dripP2P.getAllProviders().length, 0, "Providers should be available");
    }

    function registeredProvidersCountAlwaysUpToDateTest() public {
        Assert.equal(dripP2P.getProvidersCount(), 1, "Should be 1");
        dripP2P.deleteProvider();
        Assert.equal(dripP2P.getProvidersCount(), 0, "Should be 0");
    }

    function ProvidersAddrsArrayNotUpToDateTest() public {
        Assert.equal(dripP2P.getProvidersAddrs().length, 1, "Should be 1");
        dripP2P.deleteProvider();
        Assert.equal(dripP2P.getProvidersAddrs().length, 1, "Should be 1");
    }

    function ProvidersAddrsArrayUpToDateTest() public {
        Assert.equal(dripP2P.getProvidersAddrs().length, 1, "Should be 1");
        dripP2P.deleteProvider();
        dripP2P.updateProvidersAddrs();
        Assert.equal(dripP2P.getProvidersAddrs().length, 0, "Should be 0");
    }

    function autoCompleteCountdownMustBeLessThan4HTest() public {
        Assert.equal(dripP2P.getProvider(msg.sender).autoCompleteTimeLimit <= 4, true, "Should be equal to 4 hours");
        //Do a try catch to check error handling
        //try dripP2P.updateProvider(true, 5) {
        //} catch Error(string memory rslt) {}
    }
    
    function getProviderPaymentMethodsTest() public {
        //Assert.equal(dripP2P.getPaymentMethods(msg.sender) == typedef , true, "");
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////BECOME A PROVIDER REQUIREMENTS FUNCTIONS/////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   
}
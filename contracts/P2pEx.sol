//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract P2pEx is Ownable {

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////PROVIDER PROPERTIES AND CRUD FUNCTIONS///////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    struct Provider {
        address myAddress;
        bool isAvailable;
        //Time limit chosen by the provider during which the transaction will be completed(<= 4hours). Auto-comple is triggered if exceeded.
        int autoCompleteTimeLimit;
        //String in this format "payment method**currencies accepted**transfer details". '**' separator to split for display.
        string[] paymtMthds;
        //List of tokens that are deposited in contract with balance > 0
        address[] currTradedTokens;
    }
    uint8 constant MAX_PAYMT_MTHDS = 32;
    int private maxTimeLimit = 4 hours;

    mapping(address => Provider) private providers;
    //tracks addresses of registered providers. Not always up-to-date. Needs updateProvidersAddrs() to be run to be up-to-date.
    address[] private providersAddrs;
    //tracks number of currently registered providers. Updated after each addition or deletion. Always up-to-date.
    uint private registeredProvidersCount;

    /**
     * @dev Because providersAddrs is not always up-to-date, we check for address(0) addresses
     * @return currentProvidersAddys
     * Why: will be used to get info to display on front-end
     */
    function getProvidersAddys() public view returns (address[] memory currentProvidersAddys) {
        uint64 currentCounter = 0;
        for (uint count = 0; count < providersAddrs.length; count++) 
        {
            if (providers[providersAddrs[count]].myAddress == providersAddrs[count]) {
                currentProvidersAddys[currentCounter] = providersAddrs[count];
                currentCounter++;
            }
        }
        return currentProvidersAddys;
    }

    function getProvidersCount() public view returns (uint) {
        return registeredProvidersCount;
    }

    function getProvider(address _addr) public view returns (Provider memory) {
        return providers[_addr];
    }

    function getProviderAddy(address _addr) public view returns (address) {
        return providers[_addr].myAddress;
    }

    function getAllProviders() public view returns (Provider[] memory) {
        return getProviders(registeredProvidersCount, false);
    }

    function getAvailableProviders() public view returns (Provider[] memory) {
        uint availableCount = getProvidersCountByAvailability(true);
        return getProviders(availableCount, true);
    }

    function getUnavailableProviders() public view returns (Provider[] memory) {
        uint availableCount = getProvidersCountByAvailability(false);
        return getProviders(availableCount, false);
    }

    function getProviders(uint arrLength, bool _isAvailable) internal view returns (Provider[] memory) {
        Provider[] memory providersToGet = new Provider[](arrLength);
        uint providersToGetCount = 0;

        for (uint count = 0; count < providersAddrs.length; count++){
            address addyToFind = providersAddrs[count];

            if (providers[addyToFind].myAddress == addyToFind //Because providersAddrs will not always be up-to-date, we check that the provider exists
                    && ((!_isAvailable && !providers[addyToFind].isAvailable) //Unavailable providers only
                    || (_isAvailable && providers[addyToFind].isAvailable) //Available providers only
                    || arrLength == registeredProvidersCount)) { //All providers

                providersToGet[providersToGetCount] = providers[addyToFind];
                providersToGetCount++;
            }
        }

        return providersToGet;
    }

    function getProvidersCountByAvailability(bool isAvailable) internal view returns (uint) {
        uint counter = 0;
        for (uint count = 0; count < providersAddrs.length; count++){
            address addyToFind = providersAddrs[count];
            //Because providersAddrs will not be updated after each deleteProvider(), We make sure no null addresses are counted. Hence the first condition.
            if (providers[addyToFind].myAddress == addyToFind && providers[addyToFind].isAvailable == isAvailable) {
                counter++;
            }
        }

        return counter;
    }
    
    function providerExists() public view returns (bool) {
        return providers[_msgSender()].myAddress == _msgSender();
    }

    modifier onlyProvider() {
        require(providerExists(), "Provider doesn't exist");
        _;
    }

    function addProvider() public {
        require(!providerExists(), "Provider already exists");
        providers[_msgSender()] = Provider(_msgSender(), false, maxTimeLimit, new string[](0), new address[](tradeableTokens.length));
        providersAddrs.push(_msgSender());
        registeredProvidersCount++;
    }

    //*************************************************//
    //            isAvailable CRUD Start              //

    function getAvailability(address provider) external view returns (bool) {
        return providers[provider].isAvailable;
    }

    function becomeAvailable() external onlyProvider {
        if (hasAtLeastOneDeposit(_msgSender())) {
            updateAvailability(true);
        }
    }

    function becomeUnavailable() external onlyProvider {
        updateAvailability(false);
    }

    function updateAvailability(bool _isAvailable) internal {
        providers[_msgSender()].isAvailable = _isAvailable;
    }

    //            isAvailable CRUD End                  //
    //*************************************************//

    //*************************************************//
    //            isAvailable CRUD Start              //

    function addPaymtMthd(string memory _paymtMthd) public onlyProvider {
        require(providers[_msgSender()].paymtMthds.length < MAX_PAYMT_MTHDS, "Max allowed reached");
        providers[_msgSender()].paymtMthds.push(_paymtMthd);
    }

    //            isAvailable CRUD End                  //
    //*************************************************//

    function updateTimeLimit(int _timeLimit) public onlyProvider {
        require(_timeLimit <= 4, "AutoComplete time limit mustn't exceed 4 hours");
        providers[_msgSender()].autoCompleteTimeLimit = _timeLimit;
    }

    function updateProvider(bool _isAvailable, int _timeLimit, string[] memory _paymtMthds, address[] memory _tradeableTokens) public onlyProvider {
        updateTimeLimit(_timeLimit);
        updateAvailability(_isAvailable);
        providers[_msgSender()].paymtMthds = _paymtMthds;
        providers[_msgSender()].currTradedTokens = _tradeableTokens;
    }

    function deleteProvider() public onlyProvider {
        delete providers[_msgSender()];
        registeredProvidersCount--;
    }

    //update frequency to be be determined. Can also be OwnerOnly function
    function updateProvidersAddrs() public {
        for (uint count = 0; count < providersAddrs.length; count++) 
        {
            if (providers[providersAddrs[count]].myAddress != providersAddrs[count]) {
                providersAddrs[count] = providersAddrs[providersAddrs.length - 1];
                providersAddrs.pop();
            }
        }
    }

    function hasAtLeastOneDeposit(address _provider) public view returns (bool) {
        address[] memory tknList = providers[_provider].currTradedTokens;
        uint tknListSize = tknList.length;
        
        for (uint i = 0; i < tknListSize; i++) {
            if (tradeableAmountByTokenByProvider[_provider][tknList[i]] > 0) {
                return true;
            }
        }

        return false;
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////BECOME A PROVIDER REQUIREMENTS FUNCTIONS/////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // List of accepted tokens
    address[] private tradeableTokens;
    //      (Provider =>         (Token => tradeableAmount)). 
    mapping (address => mapping (address => uint)) private tradeableAmountByTokenByProvider;

    /////////////////////////////////////////////////////
    //////////// tradeableTokens CRUD start /////////////

    function getTradeableTokens() public view returns (address[] memory) {
        return tradeableTokens;
    }

    function addTradeableToken(address _newToken) public onlyOwner() {
        tradeableTokens.push(_newToken);
    }

    function removeTokenFromTrade(address _token) public onlyOwner {
        // remove from tradeableTokens
        // get providers that still have the token deposited in contract
        // send it back to their wallets  
    }
    //////////// tradeableTokens CRUD end ///////////////
    /////////////////////////////////////////////////////

    function balanceOf(address _token) public view returns (uint256){
        return IERC20(_token).balanceOf(address(this));
    }

    function getTradeableAmountByTokenByProvider(address _provider, address _token) public view returns (uint){
        return tradeableAmountByTokenByProvider[_provider][_token];
    }

    function depositToTrade(address _token, uint _tradeAmount) external payable onlyProvider {
        require(IERC20(_token).transferFrom(_msgSender(), address(this), _tradeAmount), "Transfer failed");
        tradeableAmountByTokenByProvider[_msgSender()][_token] = _tradeAmount;

        if (!providerExists()) {
            addProvider();
        }
        providers[_msgSender()].currTradedTokens.push(_token);
    }

    function isInTheReservoir() public pure returns (bool) {
        /**
        ** Has to support reservoir by having at least 25% of the value of total deposits to trade.
        ** If not, the provider is charged a transfer fee (0.5%)  
         */
        return false;
    }

    function getProviderDepositsInBnb() public view returns (uint) {
        /**
         * Need to add <address[] tokensDeposited> to Provider struct to get the info 
         * will be used in isInTheReservoir()
         */
    }

    /////////////////////////////////////////////////////
    /////////// Chainlink price feed Code start ////////

    /**
     * @notice Returns the latest price
     *
     * @return price
     */
    function getLatestPrice(address _priceFeed) public view returns (int256) {
        ( , int256 price, , , ) = AggregatorV3Interface(_priceFeed).latestRoundData();
        return price;
    }

    /////////// Chainlink price feed Code end ////////////
    /////////////////////////////////////////////////////
}
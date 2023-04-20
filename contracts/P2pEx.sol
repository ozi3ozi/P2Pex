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
        string[][] paymtMthds;
        //List of tokens that are deposited in contract with balance > 0
        address[] currTradedTokens;
    }

//Providers props
    // For each provider, each token is mapped to its index from provider.currTradedTokens
    mapping (address => mapping (address => uint)) private idxOfCurrTradedTokensByProvider;
    mapping(address => Provider) private providers;
    //      (Provider =>         (Token => tradeableAmount)). 
    mapping (address => mapping (address => uint)) private tradeableAmountByTokenByProvider;
    //tracks addresses of registered providers. Not always up-to-date. Needs updateProvidersAddrs() to be run to be up-to-date.
    address[] private providersAddrs;
    //tracks number of currently registered providers. Updated after each addition or deletion. Always up-to-date.
    uint private registeredProvidersCount;
    //Max allowed time for a provider to send the tokens to the receiver after it has been marked 'PAID'(fiat sent) by the latter 
    int private maxTimeLimit = 4 hours;
    // Contract's list of accepted tokens
    address[] private tradeableTokensLst;
    // Each token is mapped to its index from tradeableTokensLst
    mapping (address => uint) private tradeableTokens;

//String errors returned by contract functions
    string constant PROVIDER_ERROR = "provider error";
    string constant PYMT_MTHD_ERROR = "payment method error";
    string constant MAX_REACHED = "Max allowed reached";
    string constant LTE_TO_4HOURS = "Must be 4 hours or less";
    string constant TRANSFER_FAILED = "Transfer failed";
    string constant TOO_MANY = "Too many";
    string constant BALANCE_ERROR = "balance error";
    string constant ZERO_DEPOSITS_ERROR = "0 deposits error";
    string constant HAS_DEPOSITS_ERROR = "has deposits error";
    string constant TOKEN_ERROR = "Token error";
    uint8 constant MAX_PAYMT_MTHDS = 32;

    //*************************************************//
    //                  PURE FUNCTIONS                //

    //                   PURE FUNCTIONS                 //
    //*************************************************//


//                  HELPER FUNCTIONS                //

    
    function providerExists(address _provider) public view returns (bool) {
        return providers[_provider].myAddress == _provider;
    }

    /**
     * @dev 
     * @param _provider provider address
     */
    function hasAtLeastOneDeposit(address _provider) public view returns (bool) {
        address[] memory tknList = providers[_provider].currTradedTokens;

        return providerExists(_provider) && tknList.length > 0 && tradeableAmountByTokenByProvider[_provider][tknList[0]] > 0;
    }
//*************************************************//

//                    MODIFIERS                     //

    modifier onlyProvider() {
        require(providerExists(_msgSender()), PROVIDER_ERROR);
        _;
    }

    modifier isProvider(address _provider) {
        require(providerExists(_provider), PROVIDER_ERROR);
        _;
    }

    modifier hasDeposit() {
        require(hasAtLeastOneDeposit(_msgSender()), ZERO_DEPOSITS_ERROR);
        _;
    }

    modifier hasPymtMthd(uint8 _mthdIndex) {
        require(providers[_msgSender()].paymtMthds.length > _mthdIndex, PYMT_MTHD_ERROR);
        _;
    }

    modifier isTradeable(address _token) {
        require(tradeableTokens[_token] != 0, TOKEN_ERROR);
        _;
    }
//*************************************************//

//              GET PROVIDER(S) FUNCTIONS           //
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

    function getProvider(address _addr) public view isProvider(_addr) returns (Provider memory) {
        return providers[_addr];
    }

    function getProviderAddy(address _addr) public view isProvider(_addr) returns (address) {
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

    function getProviders(uint _expectedArrLength, bool _isAvailable) internal view returns (Provider[] memory) {
        Provider[] memory providersToGet = new Provider[](_expectedArrLength);
        uint providersToGetCount = 0;

        for (uint count = 0; count < providersAddrs.length; count++){
            address addyToFind = providersAddrs[count];

            if (providers[addyToFind].myAddress == addyToFind //Because providersAddrs will not always be up-to-date, we check that the provider exists
                    && ((!_isAvailable && !providers[addyToFind].isAvailable) //Unavailable providers only
                    || (_isAvailable && providers[addyToFind].isAvailable) //Available providers only
                    || _expectedArrLength == registeredProvidersCount)) { //All providers

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
//*************************************************//

//             ADD UPDATE DELETE PROVIDER           //
    function addProvider() public { // TESTED
        require(!providerExists(_msgSender()), PROVIDER_ERROR);
        providers[_msgSender()] = Provider(_msgSender(), false, maxTimeLimit, new string[][](0), new address[](0));
        providersAddrs.push(_msgSender());
        registeredProvidersCount++;
    }

    function updateProvider(bool _isAvailable, int _timeLimit, string[][] memory _paymtMthds) public onlyProvider {
        updateTimeLimit(_timeLimit);
        updateAvailability(_isAvailable);
        updateAllPaymtMthds(_paymtMthds);
    }

    function deleteProvider() public onlyProvider { // TESTED
        require(!hasAtLeastOneDeposit(_msgSender()), HAS_DEPOSITS_ERROR);
        // delete from mapping tradeableAmountByTokenByProvider
        delete providers[_msgSender()];
        registeredProvidersCount--;
    }
//*************************************************//

//                 isAvailable CRUD                 // TESTED

    function getAvailability(address provider) external view returns (bool) {
        return providers[provider].isAvailable;
    }

    function becomeAvailable() external onlyProvider hasDeposit { // TESTED
        updateAvailability(true);
    }

    function becomeUnavailable() external onlyProvider { // TESTED
        updateAvailability(false);
    }

    function updateAvailability(bool _isAvailable) internal { // TESTED INDIRECTLY
        providers[_msgSender()].isAvailable = _isAvailable;
    }
//*************************************************//

//           autoCompleteTimeLimit Start            //
    function updateTimeLimit(int _timeLimit) public onlyProvider {
        require(_timeLimit <= 4, LTE_TO_4HOURS);
        providers[_msgSender()].autoCompleteTimeLimit = _timeLimit;
    }
//*************************************************//

//                 paymtMthds CRUD                  // TESTED

    function getPymtMthds(address _provider) public view isProvider(_provider) returns (string[][] memory) { // TESTED
        return providers[_provider].paymtMthds;
    }

    /**
     * @dev list for payment method details. always length of 3: [_name, _acceptedCurrencies, _transferInfo]
     * _name like Google pay
     * _acceptedCurrencies should only contain words consisting of 3 uppercase letters. Front end validation with Regex ^(?:\b[A-Z]{3}\b\s*)+$
     * _transferInfo like an email or account number
     * @param _newpymtMthd always length of 3: [_name, _acceptedCurrencies, _transferInfo]
     */
    function addPaymtMthd(string[] memory _newpymtMthd) public onlyProvider { // TESTED
        require(providers[_msgSender()].paymtMthds.length < MAX_PAYMT_MTHDS, MAX_REACHED);
        providers[_msgSender()].paymtMthds.push([_newpymtMthd[0], _newpymtMthd[1], _newpymtMthd[2]]);
    }

    /**
     * 
     * @param _mthdIndex of payment method to remove
     */
    function removePaymtMthd(uint8 _mthdIndex) public onlyProvider hasPymtMthd(_mthdIndex) { // TESTED
        string[][] storage paymtMthds = providers[_msgSender()].paymtMthds;
        paymtMthds[_mthdIndex] = paymtMthds[paymtMthds.length - 1];
        paymtMthds.pop();
    }

    /**
     * 
     * @param _mthdIndex of payment method to update
     * @param _newPymtMthd of payment method to update
     */
    function updatePaymtMthd(uint8 _mthdIndex, string[] memory _newPymtMthd) public onlyProvider hasPymtMthd(_mthdIndex) { // TESTED
        providers[_msgSender()].paymtMthds[_mthdIndex] = _newPymtMthd;
    }

    /**
     * 
     * @param _newPymtMthds of payment method to update
     */
    function updateAllPaymtMthds(string[][] memory _newPymtMthds) public onlyProvider { // TESTED
        require(providers[_msgSender()].paymtMthds.length == _newPymtMthds.length, PYMT_MTHD_ERROR);
        providers[_msgSender()].paymtMthds = _newPymtMthds;
    }
//*************************************************//

//              currTradedTokens CRUD              //

    function getCurrTradedTokens(address _provider) external view returns (address[] memory) {
        return providers[_provider].currTradedTokens;
    }

    function getCurrTradedTokenIndex(address _token, address _provider) public view isProvider(_provider) isCurrTraded(_token) returns (uint) {
        return idxOfCurrTradedTokensByProvider[_provider][_token] - 1;
    }

    function addToCurrTradedTokens(address _token) public onlyProvider {
        if (idxOfCurrTradedTokensByProvider[_msgSender()][_token] == 0) {//Not yet added
            address[] storage tknLst = providers[_msgSender()].currTradedTokens;
            tknLst.push(_token);
            idxOfCurrTradedTokensByProvider[_msgSender()][_token] = tknLst.length;
        }
    }

    function removeFromCurrTradedTokens(address _token) public onlyProvider isCurrTraded(_token) {
        address[] storage tknLst = providers[_msgSender()].currTradedTokens;
        tknLst[getCurrTradedTokenIndex(_token, _msgSender())] = tknLst[tknLst.length - 1];
        tknLst.pop();
        delete idxOfCurrTradedTokensByProvider[_msgSender()][_token]; 
    }

    modifier isCurrTraded(address _token) {
        require(idxOfCurrTradedTokensByProvider[_msgSender()][_token] != 0, TOKEN_ERROR);
        _;
    }

//*************************************************//

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
//*************************************************//

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////BECOME A PROVIDER REQUIREMENTS FUNCTIONS/////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//*************************************************//
//            tradeableTokensLst CRUD             //

    function getTradeableTokensLst() public view returns (address[] memory) {
        return tradeableTokensLst;
    }

    function getTradeableTokenIndex(address _token) public view isTradeable(_token) returns (uint) {// TESTED
        return tradeableTokens[_token] - 1;
    }

    /**
     * @dev Because tradeableTokens[_NotYetAddedToken] will return 0(default uint value),
     * we map the new token added to the new length of tradeableTokensLst.
     * @param _newToken token to be added
     */
    function makeTokenTradeable(address _newToken) public onlyOwner() {// TESTED
        require(tradeableTokens[_newToken] == 0, TOKEN_ERROR);
        tradeableTokensLst.push(_newToken);
        tradeableTokens[_newToken] = tradeableTokensLst.length;
    }

    function removeTokenFromTrade(address _token) public onlyOwner isTradeable(_token) {
        tradeableTokensLst[getTradeableTokenIndex(_token)] = tradeableTokensLst[tradeableTokensLst.length - 1];
        tradeableTokensLst.pop();
        delete tradeableTokens[_token];
        // get providers that still have the token deposited in contract
        // send it back to their wallets  
    }
//*************************************************//

//*************************************************//
//               tradeableTokens CRUD             //

//*************************************************//

    function balanceOf(address _token) public view returns (uint256){
        return IERC20(_token).balanceOf(address(this));
    }

    function getTradeableAmountByTokenByProvider(address _token, address _provider) public view returns (uint){
        return tradeableAmountByTokenByProvider[_provider][_token];
    }

    /**
     * 
     * @param _token from a drop-down-list generated from tradeableTokensLst.
     * @param _tradeAmount amount to be deposited in contract.
     */
    function depositToTrade(address _token, uint _tradeAmount) external payable onlyProvider isTradeable(_token) {
        require(IERC20(_token).transferFrom(_msgSender(), address(this), _tradeAmount), TRANSFER_FAILED);
        tradeableAmountByTokenByProvider[_msgSender()][_token] += _tradeAmount;
        addToCurrTradedTokens(_token); // Only added if new
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

//*************************************************//
//          Chainlink price feed Code start       //

    /**
     * @notice Returns the latest price
     *
     * @return price
     */
    function getLatestPrice(address _priceFeed) public view returns (int256) {
        ( , int256 price, , , ) = AggregatorV3Interface(_priceFeed).latestRoundData();
        return price;
    }
}
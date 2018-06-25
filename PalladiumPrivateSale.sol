pragma solidity ^0.4.18;

import './math/SafeMath.sol';
import './ownership/Ownable.sol';
import './PalladiumToken.sol';

contract PalladiumTokenSale is Ownable{
	using SafeMath for uint256;

	// Private sale token
	PalladiumToken public token;

  // amount of tokens in existance - 180mil Palladium = 18e25 Tracks
  uint256 public constant TOTAL_NUM_TOKENS = 18e25; // 1 Palladium = 1e18 Tracks, all units in contract in Tracks
  uint256 public constant tokensForSale = 144e24; // 80% of all tokens

  // totalEthers received
  uint256 public totalEthers = 0;

  // Minimal possible cap in ethers
  uint256 public constant softCap = 2000 ether; // TODO - set value at time of deployment
  // Maximum possible cap in ethers
  uint256 public constant hardCap = 57600 ether; // TODO - set value at time of deployment

  uint256 public constant presaleLimit = 57600 ether; // TODO - set value at time of deployment
  bool public presaleLimitReached = false;

  // Minimum and maximum investments in Ether
  uint256 public constant min_investment_eth = 0.5 ether; // fixed value, not changing
  uint256 public constant max_investment_eth = 200 ether; // TODO - set value at time of deployment

  // TODO - set minimum investmet za presale na 5ETH
  uint256 public constant min_investment_presale_eth = 1 ether; // fixed value, not changing

  // refund if softCap is not reached
  bool public refundAllowed = false;

  // amounts of tokens for legal, team, advisors, founders, oemPartnership and futureDevelopment
  uint256 public constant legalExpense = 1152e22; // 8% legal
  uint256 public constant marketingAndAdvisors = 1152e22; // 8% marketing
  // uint256 public constant founderReward;
  uint256 public constant oemPartnership = 1152e22; // 8% oemPartnership
  uint256 public constant futureDevelopment = 4032e22; // 28% for future development
  uint256 public constant stabilityFund = 4032e22;  // 28% team and advisors

  uint256 public leftOverTokens = 0;

  uint256[8] public founderAmounts = [uint256(45e23),45e23,45e23,45e23,45e23,45e23,45e23,45e23];
  uint256[2] public marketingAndAdvisorsAmounts = [ uint256(576e22),576e22];


  // Withdraw multisig wallet
  address public wallet;

  // Withdraw multisig wallet
  address public stabilityFundWallet;

  // Withdraw multisig wallet
  address public advisorsAndMarket;

  // Token per ether
  uint256 public constant token_per_wei = 8500; // TODO : peg Palladium to ether here

  // start and end timestamp where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  uint256 private constant weekInSeconds = 86400 * 7;

  // whitelist addresses and planned investment amounts
  mapping(address => uint256) public whitelist;

  // amount of ether received from token buyers
  mapping(address => uint256) public etherBalances;

  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event Whitelist(address indexed beneficiary, uint256 value);
  event SoftCapReached();
  event Finalized();

  function PalladiumTokenSale(uint256 _startTime, address _wallet, address _stabilityFundWallet, address _advisorsAndMarket) public {
    require(_startTime >=  now);
    require(_wallet != 0x0);
    require(_stabilityFundWallet != 0x0);
    require(_advisorsAndMarket != 0x0);

    token = new PalladiumToken();
    wallet = _wallet;
    stabilityFundWallet = _stabilityFundWallet;
    advisorsAndMarket = _advisorsAndMarket;
    startTime = _startTime;
    endTime = _startTime + 16 * weekInSeconds; // the sale lasts a maximum of 17 weeks

  }
    /*
     * @dev fallback for processing ether
     */
     function() public payable {
       return buyTokens(msg.sender);
     }

     function calcAmount() internal constant returns (uint256) {
      require(now<=endTime);

      if (totalEthers >= presaleLimit || startTime + 16 * weekInSeconds  < now ){
        // presale has ended
        return msg.value.mul(token_per_wei);
        }else{
          // presale ongoing
          // do not allow less than min_investment_presale_eth investments
          require(msg.value >= min_investment_presale_eth);

          /* discount 20 % in the first month - presale month 1 */
          if (now <= startTime + 4 * weekInSeconds) {
            return msg.value.mul(token_per_wei.mul(100)).div(80);

          }

          /* discount 15 % in the second month - presale month 2 */
          if ( startTime + 4 * weekInSeconds   < now  && now <= startTime + 4 * weekInSeconds) {
           return msg.value.mul(token_per_wei.mul(100)).div(85);
         }
				 /* discount 10 % in the third month - presale month 3 */
				 if ( startTime +  8 * weekInSeconds   < now  && now <= startTime + 4 * weekInSeconds) {
					return msg.value.mul(token_per_wei.mul(100)).div(90);
				 }
					/* discount 5 % in the fourth month - presale month 4 */
          if ( startTime + 12 * weekInSeconds   < now  && now <= startTime + 4 * weekInSeconds) {
           return msg.value.mul(token_per_wei.mul(100)).div(95);
       }

     }

    /*
     * @dev sell token and send to contributor address
     * @param contributor address
     */
     function buyTokens(address contributor) public payable {
       require(!hasEnded());
       require(validPurchase());
       require(checkWhitelist(contributor,msg.value));
       uint256 amount = calcAmount();
       require((token.totalSupply() + amount) <= TOTAL_NUM_TOKENS);

       whitelist[contributor] = whitelist[contributor].sub(msg.value);
       etherBalances[contributor] = etherBalances[contributor].add(msg.value);

       totalEthers = totalEthers.add(msg.value);

       token.mint(contributor, amount);
       require(totalEthers <= hardCap);
       TokenPurchase(0x0, contributor, msg.value, amount);
     }


     // @return user balance
     function balanceOf(address _owner) public constant returns (uint256 balance) {
      return token.balanceOf(_owner);
    }

    function checkWhitelist(address contributor, uint256 eth_amount) public constant returns (bool) {
     require(contributor!=0x0);
     require(eth_amount>0);
     return (whitelist[contributor] >= eth_amount);
   }

   function addWhitelist(address contributor, uint256 eth_amount) onlyOwner public returns (bool) {
     require(!hasEnded());
     require(contributor!=0x0);
     require(eth_amount>0);
     Whitelist(contributor, eth_amount);
     whitelist[contributor] = eth_amount;
     return true;
   }

   function addWhitelists(address[] contributors, uint256[] amounts) onlyOwner public returns (bool) {
     require(!hasEnded());
     address contributor;
     uint256 amount;
     require(contributors.length == amounts.length);

     for (uint i = 0; i < contributors.length; i++) {
      contributor = contributors[i];
      amount = amounts[i];
      require(addWhitelist(contributor, amount));
    }
    return true;
  }


  function validPurchase() internal constant returns (bool) {

   bool withinPeriod = now >= startTime && now <= endTime;
   bool withinPurchaseLimits = msg.value >= min_investment_eth && msg.value <= max_investment_eth;
   return withinPeriod && withinPurchaseLimits;
 }

 function hasStarted() public constant returns (bool) {
  return now >= startTime;
}

function hasEnded() public constant returns (bool) {
  return now > endTime || token.totalSupply() == TOTAL_NUM_TOKENS;
}


function hardCapReached() constant public returns (bool) {
  return hardCap.mul(999).div(1000) <= totalEthers;
}

function softCapReached() constant public returns(bool) {
  return totalEthers >= softCap;
}


function withdraw() onlyOwner public {
  require(softCapReached());
  require(this.balance > 0);

  wallet.transfer(this.balance);
}

function withdrawTokenToFounders() onlyOwner public {
  require(softCapReached());
  require(hasEnded());

  if (now > startTime + 360 days && founderAmounts[7]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[7]);
    founderAmounts[7] = 0;
  }

  if (now > startTime + 330 days && founderAmounts[6]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[6]);
    founderAmounts[6] = 0;
  }
  if (now > startTime + 300 days && founderAmounts[5]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[5]);
    founderAmounts[5] = 0;
  }
  if (now > startTime + 270 days && founderAmounts[4]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[4]);
    founderAmounts[4] = 0;
  }
  if (now > startTime + 240 days&& founderAmounts[3]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[3]);
    founderAmounts[3] = 0;
  }
  if (now > startTime + 210 days && founderAmounts[2]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[2]);
    founderAmounts[2] = 0;
  }
  if (now > startTime + 180 days && founderAmounts[1]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[1]);
    founderAmounts[1] = 0;
  }
  if (now > startTime + 90 days && founderAmounts[0]!=0){
    token.transfer(stabilityFundWallet, founderAmounts[0]);
    founderAmounts[0] = 0;
  }
}

function withdrawTokensToAdvisors() onlyOwner public {
  require(softCapReached());
  require(hasEnded());

  if (now > startTime + 180 days && AndAdvisorsAmounts[1]!=0){
    token.transfer(advisorsAndmarket, marketAndAdvisorsAmounts[1]);
    marketAndAdvisorsAmounts[1] = 0;
  }

  if (now > startTime + 90 days && marketAndAdvisorsAmounts[0]!=0){
    token.transfer(advisorsAndMarket, marketAndAdvisorsAmounts[0]);
    marketAndAdvisorsAmounts[0] = 0;
  }
}

function refund() public {
  require(refundAllowed);
  require(hasEnded());
  require(!softCapReached());
  require(etherBalances[msg.sender] > 0);
  require(token.balanceOf(msg.sender) > 0);

  uint256 current_balance = etherBalances[msg.sender];
  etherBalances[msg.sender] = 0;
  token.transfer(this,token.balanceOf(msg.sender)); // burning tokens by sending back to contract
  msg.sender.transfer(current_balance);
}


function finishCrowdsale() onlyOwner public returns (bool){
  require(!token.mintingFinished());
  require(hasEnded() || hardCapReached());

  if(softCapReached()) {
    token.mint(wallet, legalExpense);
    token.mint(advisorsAndMarket,  marketAndAdvisors.div(5)); //20% available immediately
    token.mint(wallet, oemPartnership);
    token.mint(wallet, futureDevelopment);
    token.mint(this, stabilityFund);
    token.mint(this, marketAndAdvisors.mul(4).div(5));
    #leftOverTokens = TOTAL_NUM_TOKENS.sub(token.totalSupply());
    #token.mint(wallet,leftOverTokens); // will be equaly distributed among all presale and sale contributors after the sale

    token.doneMinting(true);
    return true;
    } else {
      refundAllowed = true;
      token.doneMinting(false);
      return false;
    }

    Finalized();
  }

}

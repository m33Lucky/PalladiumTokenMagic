pragma solidity ^0.4.18;

import './math/SafeMath.sol';
import './ownership/Ownable.sol';
import './xPalladiumToken.sol';

contract xPalladiumTokenSale is Ownable{
	using SafeMath for uint256;

	// Presale token
	xPalladiumToken public token;

  // amount of tokens in existance - 180mil xPalladiumToken = 18e25 Tracks
  uint256 public constant TOTAL_NUM_TOKENS = 18e25; // 1 xPalladiumToken = 1e18 Tracks, all units in contract in Tracks
  uint256 public constant tokensForSale = 144e24; // 80% of all tokens

  // totalEthers received
  uint256 public totalEthers = 0;

  // Minimal possible cap in ethers
  uint256 public constant softCap = 1600 ether; // TODO - set value at time of deployment
  // Maximum possible cap in ethers
  uint256 public constant hardCap = 57000 ether; // TODO - set value at time of deployment

  uint256 public constant presaleLimit = 28800 ether; // TODO - set value at time of deployment
  bool public presaleLimitReached = false;

  // Minimum and maximum investments in Ether
  uint256 public constant min_investment_eth = 2 ether; // fixed value, not changing
  uint256 public constant max_investment_eth = 200 ether; // TODO - set value at time of deployment

  // TODO - set minimum investmet for private sale A 
  uint256 public constant min_investment_presale_eth = 3 ether; // fixed value, not changing

  // refund if softCap is not reached
  bool public refundAllowed = false;

  // amounts of tokens for bounty, team, advisors, founders, liquidityPool and futureDevelopment
  uint256 public constant bountyReward = 144e23; // 8% bounty/legal
  uint256 public constant preicoAndAdvisors = 144e23; // 8% preICO and advisors/marketers
  // uint256 public constant founderReward;
  uint256 public constant liquidityPool = 504e23; // 28% liquidityPool/stability fund
  uint256 public constant futureDevelopment = 504e23; // 28% for future development
  uint256 public constant teamAndFounders = 144e23;  // 8% team members
  //uint256 public constant reservedAmount = 36e24; // 20% total reserved balance
  uint256 public leftOverTokens = 0;

  uint256[8] public founderAmounts = [uint256(45e23),45e23,45e23,45e23,45e23,45e23,45e23,45e23];
  uint256[2]  public preicoAndAdvisorsAmounts = [ uint256(288e22),288e22];

  // tells if tokens have been burned already //
	bool burned;

  // Withdraw multisig wallet
  address public wallet;

  // Withdraw multisig wallet
  address public teamAndFoundersWallet;

  // Withdraw multisig wallet
  address public advisorsAndPreICO;

  // Token per ether
  uint256 public constant token_per_wei = 8500; // TODO : peg xPalladiumToken to ether here

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
  event Burned(uint256 xamount);

  function xPalladiumTokenSale(uint256 _startTime, address _wallet, address _teamAndFoundersWallet, address _advisorsAndPreICO) public {
    require(_startTime >=  now);
    require(_wallet != 0x0);
    require(_teamAndFoundersWallet != 0x0);
    require(_advisorsAndPreICO != 0x0);

    token = new xPalladiumToken();
    wallet = _wallet;
    teamAndFoundersWallet = _teamAndFoundersWallet;
    advisorsAndPreICO = _advisorsAndPreICO;
    startTime = _startTime;
    endTime = _startTime + 12 * weekInSeconds; // the sale lasts a maximum of 13 weeks

  }
    /*
     * @dev fallback for processing ether
     */
     function() public payable {
       return buyTokens(msg.sender);
     }

     function calcAmount() internal constant returns (uint256) {
      require(now<=endTime);

      if (totalEthers >= presaleLimit || startTime + 6 * weekInSeconds  < now ){
        // presale has ended
        return msg.value.mul(token_per_wei);
        }else{
          // presale ongoing
          // do not allow less than min_investment_presale_eth investments
          require(msg.value >= min_investment_presale_eth);

          /* discount 20 % in the first 6 weeks - private sale A  */
          if (now <= startTime + weekInSeconds) {
            return msg.value.mul(token_per_wei.mul(100)).div(80);

          }

          /* discount 15 % in the next 6 week - private sale B */
          if ( startTime +  weekInSeconds   < now  && now <= startTime + 6 * weekInSeconds) {
           return msg.value.mul(token_per_wei.mul(100)).div(85);
         }
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
    token.transfer(teamAndFoundersWallet, founderAmounts[7]);
    founderAmounts[7] = 0;
  }

  if (now > startTime + 330 days && founderAmounts[6]!=0){
    token.transfer(teamAndFoundersWallet, founderAmounts[6]);
    founderAmounts[6] = 0;
  }
  if (now > startTime + 310 days && founderAmounts[5]!=0){
    token.transfer(teamAndFoundersWallet, founderAmounts[5]);
    founderAmounts[5] = 0;
  }
  if (now > startTime + 280 days && founderAmounts[4]!=0){
    token.transfer(teamAndFoundersWallet, founderAmounts[4]);
    founderAmounts[4] = 0;
  }
  if (now > startTime + 250 days&& founderAmounts[3]!=0){
    token.transfer(teamAndFoundersWallet, founderAmounts[3]);
    founderAmounts[3] = 0;
  }
  if (now > startTime + 220 days && founderAmounts[2]!=0){
    token.transfer(teamAndFoundersWallet, founderAmounts[2]);
    founderAmounts[2] = 0;
  }
  if (now > startTime + 190 days && founderAmounts[1]!=0){
    token.transfer(teamAndFoundersWallet, founderAmounts[1]);
    founderAmounts[1] = 0;
  }
  if (now > startTime + 160 days && founderAmounts[0]!=0){
    token.transfer(teamAndFoundersWallet, founderAmounts[0]);
    founderAmounts[0] = 0;
  }
}

function withdrawTokensToAdvisors() onlyOwner public {
  require(softCapReached());
  require(hasEnded());

  if (now > startTime + 180 days && preicoAndAdvisorsAmounts[1]!=0){
    token.transfer(advisorsAndPreICO, preicoAndAdvisorsAmounts[1]);
    preicoAndAdvisorsAmounts[1] = 0;
  }

  if (now > startTime + 90 days && preicoAndAdvisorsAmounts[0]!=0){
    token.transfer(advisorsAndPreICO, preicoAndAdvisorsAmounts[0]);
    preicoAndAdvisorsAmounts[0] = 0;
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
    token.mint(wallet, bountyReward);
    token.mint(advisorsAndPreICO,  preicoAndAdvisors.div(5)); //20% available immediately
    token.mint(wallet, liquidityPool);
    token.mint(wallet, futureDevelopment);
    token.mint(this, teamAndFounders);
    token.mint(this, preicoAndAdvisors.mul(4).div(5));
    leftOverTokens = TOTAL_NUM_TOKENS.sub(token.totalSupply());
    //token.mint(wallet,leftOverTokens); // will be equaly distributed among all presale and sale contributors after the sale

    token.doneMinting(true);
    return true;
    } else {
      refundAllowed = true;
      token.doneMinting(false);
      return false;
    }


    Finalized();
  }
  /* to be called when Private sale is closed. burns the remaining tokens except the company share (36e24), the tokens reserved
	 *  for the bounty/advisors/marketing program (144e23), for the stability program (504e23) and for future financing of the company (504e23).
	 *  anybody may burn the tokens after private sale ended, but only once  */
    function burn() public {
		//if tokens have not been burned already and the private sale ended
		if (!burned && now > startTime) {
			uint256 difference = leftOverTokens;

			burned = true;
			Burned(difference);}
}
}

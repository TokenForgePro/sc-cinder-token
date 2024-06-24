# Cindr Token

Cindr is a decentralized, deflationary token inspired by Safemoon's mechanisms and code. It features automatic liquidity generation, burn mechanisms, and rewards for holders.

## Features

- **Automatic Liquidity Generation:** A portion of each transaction is used to add liquidity to Uniswap, ensuring continuous liquidity and reducing volatility.

- **Burn Mechanism:** A portion of each transaction is burned, reducing the total supply over time and creating a deflationary effect.

- **Rewards for Holders:** A portion of each transaction is redistributed to existing holders, incentivizing holding and reducing selling pressure.
- **Marketing and Development Fees:** Portions of each transaction are allocated for marketing and development efforts, ensuring continuous growth and improvement of the project.

## Tokenomics

- **Total Supply:** Configurable by the owner
- **Decimals:** 9
- **Tax Fee:** Configurable by the owner
- **Burn Fee:** Configurable by the owner
- **Liquidity Fee:** Configurable by the owner
- **Marketing Fee:** Configurable by the owner

## Inspired by Safemoon

Cindr takes inspiration from the Safemoon token, which gained popularity for its innovative approach to rewarding holders and reducing supply through burn mechanisms. By incorporating similar features, Cindr aims to provide a robust and rewarding token for its community.

## Deployment

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) library

### Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/your-repo/sc-reflection-token.git
   cd Cindr-token
   ```

2. **Create .env file**
   Create a .env file in the root directory and add your mainnet RPC URL:

   ```
   MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID
   ```

3. **Install Dependencies**

   ```bash
   forge install
   ```

4. **Compile the Contracts**

   ```bash
   forge build
   ```

### Deployment

1. **Deploy Using Foundry**

   Modify the deployment script with your desired parameters:

   ```solidity
   // deploy/CindrDeploy.sol

   import { Cindr } from "../src/Cindr.sol";
   import { Script } from "forge-std/Script.sol";

   contract CindrDeploy is Script {
       function run() external {
           uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
           vm.startBroadcast(deployerPrivateKey);

           new Cindr(
               "Cindr Token",           // Name
               "Cindr",                 // Symbol
               0xYourRouterAddress,      // UniswapV2Router Address
               0xYourMarketingWallet    // Marketing Wallet Address
           );

           vm.stopBroadcast();
       }
   }
   ```

   Deploy the contract:

   ```bash
   forge script deploy/CindrDeploy.sol --broadcast
   ```

## Usage

### Interacting with the Contract

Once deployed, you can interact with the contract using standard ERC20 functions and additional features provided by the Cindr contract.

#### Standard ERC20 Functions

- **Transfer Tokens:**

  ```solidity
  function transfer(address to, uint256 amount) public returns (bool);
  ```

- **Approve Tokens:**

  ```solidity
  function approve(address spender, uint256 amount) public returns (bool);
  ```

- **Transfer Tokens from an Address:**

  ```solidity
  function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
  ```

- **Check Balance:**

  ```solidity
  function balanceOf(address account) public view returns (uint256);
  ```

- **Check Allowance:**

  ```solidity
  function allowance(address owner, address spender) public view returns (uint256);
  ```

#### Cindr-Specific Functions

- **Exclude from Fee:**

  ```solidity
  function excludeFromFee(address account) public onlyOwner;
  ```

- **Include in Fee:**

  ```solidity
  function includeInFee(address account) public onlyOwner;
  ```

- **Set Tax Fee Percent:**

  ```solidity
  function setTaxFeePercent(uint8 taxFee) external onlyOwner;
  ```

- **Set Burn Fee Percent:**

  ```solidity
  function setBurnFeePercent(uint8 burnFee) external onlyOwner;
  ```

- **Set Liquidity Fee Percent:**

  ```solidity
  function setLiquidityFeePercent(uint8 liquidityFee) external onlyOwner;
  ```

- **Set Marketing Fee Percent:**

  ```solidity
  function setMarketingFeePercent(uint8 marketingFee) external onlyOwner;
  ```

- **Set Development Fee Percent:**

  ```solidity
  function setDevelopmentFeePercent(uint8 developmentFee) external onlyOwner;
  ```

- **Set Max Transaction Amount:**

  ```solidity
  function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner;
  ```

- **Enable/Disable Swap and Liquify:**

  ```solidity
  function setSwapAndLiquifyEnabled(bool enabled) public onlyOwner;
  ```

## Acknowledgements

- Inspired by the [Safemoon](https://github.com/safemoonprotocol/Safemoon.sol/blob/main/Safemoon.sol) token and its innovative mechanisms.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

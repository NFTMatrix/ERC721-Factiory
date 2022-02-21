// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

enum WhitelistType { 
    NONE,
    SIGNATURE,
    STORAGE
}

struct AdvancedConfigurator { 
    bool canContractMint;
    bool whitelistCountMints;
    bool sameMintCountForBothSales;
    uint256 giftMintCount;
}

struct Configurator { 
   string name;
   string symbol;
   uint256 maxSupply;
   uint256 mintPrice;
   uint256 mintPerAccount;
   WhitelistType whitelistType;
   AdvancedConfigurator advanced;
}
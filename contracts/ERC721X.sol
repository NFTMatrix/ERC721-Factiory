// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./ERC721XConfigurator.sol";
import "./ReentrancyGuard.sol";
import "./Signable.sol";

contract ERC721X is ERC721Enumerable, Signable, ReentrancyGuard {
    using Counters for Counters.Counter;

    enum Phase { NONE, WHITELIST_SALE, MAIN_SALE }

    // Phase
    Phase private _phase;

    // Counter
    Counters.Counter private _tokenCount;

    // Minting by account on different phases
    mapping(address => uint256) private _mintedPreSales;
    mapping(address => uint256) private _mintedMainSales;
    mapping(address => uint256) private _whitelist;

    // Base URI
    string private _baseTokenURI;

    Configurator public configurator;

    // Flag
    bool private gotOwnersMints = false;

    modifier costs(uint price) {
        require(msg.value >= price, "msg.value should be more or eual than price");   
        _;
    }

    constructor() 
        ERC721("", "")
    {
        string memory baseTokenURI = "https://digitalanimals.club/animal/";

        _baseTokenURI = baseTokenURI;
    }

    receive() external payable { }

    fallback() external payable { }

    function init(Configurator memory configurator_) public {
        configurator = configurator_;
    }

    function name() public view virtual override returns (string memory) {
        return configurator.name;
    }

    function symbol() public view virtual override returns (string memory) {
        return configurator.symbol;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseTokenURI = baseURI_;
    }

    function mintForOwners() public onlyOwner lock { 
        require(gotOwnersMints == false, "Already minted");
        uint256 amount = configurator.advanced.giftMintCount;

        uint256 total = totalToken();
        require(total + amount <= maxSupply(), "Max Supply Reached");

        for (uint i; i < amount; i++) {
            _tokenCount.increment();
            _safeMint(msg.sender, totalToken());
        }

        gotOwnersMints = true;
    }

    function mint(uint256 amount) public payable {
        require(phase() != Phase.NONE, "Phase shoudn't be NONE");

        if (phase() == Phase.WHITELIST_SALE) {
            require(configurator.whitelistType == WhitelistType.STORAGE, "Invalid whitelist type");
            _mint(amount, _whitelist[msg.sender], Phase.WHITELIST_SALE);
        } else {
            _mint(amount, configurator.mintPerAccount, Phase.MAIN_SALE);
        }
    }

    function mint(uint256 amount, uint256 maxAmount, bytes calldata signature) public payable {
        require(phase() != Phase.NONE, "Phase shoudn't be NONE");
        require(configurator.whitelistType == WhitelistType.SIGNATURE, "Invalid whitelist type");
        require(_verify(signer(), _hash(msg.sender, maxAmount), signature), "Invalid signature");
        _mint(amount, maxAmount, Phase.WHITELIST_SALE);
    }

    function mintPrice() public view returns (uint256) {
        return configurator.mintPrice;
    }

    function maxSupply() public view returns (uint256) {
        return configurator.maxSupply;
    }

    function mintedAllSales(address operator) public view returns (uint256) {
        require(shouldTrackMintCount(), "Minted all sales is not count with current configuration");
        return _mintedMainSales[operator] + _mintedPreSales[operator];
    }

    function phase() public view returns (Phase) {
        return _phase;
    }

    function totalToken() public view returns (uint256) {
        return _tokenCount.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function shouldTrackMintCount() private view returns (bool) {
        return configurator.mintPerAccount > 0 || configurator.advanced.whitelistCountMints;
    }

    function _mint(uint256 amount, uint256 maxAmount, Phase phase_) costs(mintPrice() * amount) private lock {
        if (configurator.advanced.canContractMint == false) {
            require(!Address.isContract(msg.sender), "Address is contract");
        }

        uint256 total = totalToken();
        require(total + amount <= maxSupply(), "Max Supply Reached");

        if (shouldTrackMintCount()) {
            if (phase_ == Phase.WHITELIST_SALE && configurator.advanced.whitelistCountMints) {
                if (configurator.advanced.sameMintCountForBothSales) {
                    uint256 minted = _mintedMainSales[msg.sender];
                    require(minted + amount <= maxAmount, "Already minted maximum");
                    _mintedMainSales[msg.sender] = minted + amount;
                } else {
                    uint256 minted = _mintedPreSales[msg.sender];
                    require(minted + amount <= maxAmount, "Already minted maximum");
                    _mintedPreSales[msg.sender] = minted + amount;
                }
            } else if (phase_ == Phase.MAIN_SALE) {
                uint256 minted = _mintedMainSales[msg.sender];
                require(minted + amount <= maxAmount, "Already minted maximum");
                _mintedMainSales[msg.sender] = minted + amount;
            }
        }
        
        for (uint i; i < amount; i++) {
            _tokenCount.increment();
            _safeMint(msg.sender, totalToken());
        }
    }

    function _verify(address signer, bytes32 hash, bytes memory signature) private pure returns (bool) {
        return signer == ECDSA.recover(hash, signature);
    }
    
    function _hash(address account, uint256 amount) private pure returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(account, amount)));
    }
}
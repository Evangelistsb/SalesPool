// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract SalesPool is ReentrancyGuard, IERC721Receiver {
    using Counters for Counters.Counter;
    Counters.Counter private _id;
    Counters.Counter private _soldItems;

    // wallet address of contract deployer
    address payable private admin;

    // minimum price. See it as rent for placing item in market
    uint256 private listingPrice;

    /// @dev structure of each Sale item
    struct SaleItem {
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => SaleItem) private idToSaleItem;
    // keeps track of items listed for sale by a user
    mapping(address => uint) public itemsListedCount;
    // keeps track of items bought by a user
    mapping(address => uint) public itemsBoughtCount;

    /// @dev event to be emitted when new sale item is added to market
    event SaleItemCreated(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    constructor(uint256 _listingPrice) {
        admin = payable(msg.sender);
        listingPrice = _listingPrice;
    }

    /// @dev returns the listing price of the contract
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /// @dev only owner can set listing price of contract
    /// @notice function is callable only by admin
    function setListingPrice(uint256 _newPrice) public {
        require(msg.sender == admin, "Only admin can carry out this operation");
        listingPrice = _newPrice;
    }

    /// @dev places an item for sale on the marketplace
    function createSaleItem(
        address nftContract,
        uint256 tokenId,
        uint256 marketPrice
    ) external payable nonReentrant {
        require(nftContract != address(0), "Invalid contract address");
        require(marketPrice > 0, "Price on item must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Funds sent not enough to add item to market"
        );

        uint256 itemId = _id.current();
        _id.increment();

        idToSaleItem[itemId] = SaleItem(
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            marketPrice,
            false
        );
        itemsListedCount[msg.sender]++;
        require(
            IERC721(nftContract).getApproved(tokenId) == address(this) &&
                IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "Caller is not owner or contract hasn't been approved"
        );
        // Please ensure you own `tokenId` or you are approved to transfer before calling this function
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        emit SaleItemCreated(
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            marketPrice,
            false
        );

        if (listingPrice > 0) {
            // transfer amount used to add item to market to the contract owner
            (bool success, ) = admin.call{value: listingPrice}("");
            require(success, "Transfer of listing fee failed");
        }
    }

    /// @dev buy an item with id of itemId from the market
    function buyItem(uint256 itemId) external payable nonReentrant {
        require(!idToSaleItem[itemId].sold, "sold");
        require(
            idToSaleItem[itemId].seller != msg.sender,
            "you can't buy your own item"
        );
        uint price = idToSaleItem[itemId].price;
        require(
            msg.value == idToSaleItem[itemId].price,
            "Please submit the asking price in order to complete the purchase"
        );
        idToSaleItem[itemId].price = 0;
        itemsBoughtCount[msg.sender]++;
        (bool success, ) = payable(idToSaleItem[itemId].seller).call{
            value: price
        }("");
        require(success, "Transfer failed");
        IERC721(idToSaleItem[itemId].nftContract).transferFrom(
            address(this),
            msg.sender,
            idToSaleItem[itemId].tokenId
        );
        idToSaleItem[itemId].owner = payable(msg.sender);
        idToSaleItem[itemId].sold = true;
        _soldItems.increment();
    }

    // fetch and return all items still available for sale in market
    function getAvailableSalesItem() public view returns (SaleItem[] memory) {
        uint256 itemCount = _id.current();
        uint256 itemsAvailableCount = _id.current() - _soldItems.current();
        uint256 currentIndex = 0;

        SaleItem[] memory items = new SaleItem[](itemsAvailableCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToSaleItem[i].owner == address(0) && !idToSaleItem[i].sold) {
                items[currentIndex] = idToSaleItem[i];
                currentIndex += 1;
            }
        }
        return items;
    }

    // get all items current logged in user has purchased
    function getMyItems() public view returns (SaleItem[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = itemsBoughtCount[msg.sender];
        uint256 length = _id.current();

        SaleItem[] memory myItems = new SaleItem[](itemCount);
        for (uint256 i = 0; i < length; i++) {
            if (idToSaleItem[i].owner == msg.sender) {
                myItems[currentIndex] = idToSaleItem[i];
                currentIndex += 1;
            }
        }
        return myItems;
    }

    /// @dev get all items created in the market by the current logged in user
    function saleItemsCreated() public view returns (SaleItem[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = itemsListedCount[msg.sender];
        uint256 length = _id.current();

        SaleItem[] memory saleItems = new SaleItem[](itemCount);
        for (uint256 i = 0; i < length; i++) {
            if (idToSaleItem[i].seller == msg.sender) {
                saleItems[currentIndex] = idToSaleItem[i];
                currentIndex += 1;
            }
        }

        return saleItems;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return bytes4(this.onERC721Received.selector);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SalesPool is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _id;
    Counters.Counter private _soldItems;

    // wallet address of contract deployer
    address payable admin;

    // minimum price. See it as rent for placing item in market
    uint256 private listingPrice;

    // structure of each Sale item
    struct SaleItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    } 

    mapping(uint256 => SaleItem) private idToSaleItem;

    // event to be emitted when new sale item is added to market
    event SaleItemCreated(
        uint256 indexed itemId,
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

    // returns the listing price of the contract
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    // only owner can set listing price of contract
    function setListingPrice(uint256 _newPrice) public {
        require(msg.sender == admin, "Only admin can carry out this operation");
        listingPrice = _newPrice;
    }

    // places an item for sale on the marketplace
    function createSaleItem(
        address nftContract,
        uint256 tokenId,
        uint256 marketPrice
    ) public payable nonReentrant {
        require(marketPrice > 0, "Price on item must be at least 1 wei");
        require(
            msg.value >= listingPrice,
            "Funds sent not enough to add item to market"
        );
        
        _id.increment();
        uint256 itemId = _id.current();        

        idToSaleItem[itemId] = SaleItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            marketPrice,
            false
        );

        // Please ensure you own `tokenId` or you are approved to transfer before calling this function
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        emit SaleItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            marketPrice,
            false
        );
    }

    // buy an item with id of itemId from the market
    function buyItem(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        uint256 price = idToSaleItem[itemId].price;
        uint256 tokenId = idToSaleItem[itemId].tokenId;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        idToSaleItem[itemId].seller.transfer(msg.value);
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToSaleItem[itemId].owner = payable(msg.sender);
        idToSaleItem[itemId].sold = true;
        _soldItems.increment();

        // transfer amount used to add item to market to the contract owner
        payable(admin).transfer(listingPrice);
    }

    // fetch and return all items still available for sale in market
    function getAvailableSalesItem()
        public
        view
        returns (SaleItem[] memory)
    {
        uint256 itemCount = _id.current();
        uint256 itemsAvailableCount = _id.current() - _soldItems.current();
        uint256 counter = 0;

        SaleItem[] memory items = new SaleItem[](itemsAvailableCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToSaleItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                SaleItem storage currentItem = idToSaleItem[
                    currentId
                ];
                items[counter] = currentItem;
                counter += 1;
            }
        }
        return items;
    }

    // get all items current logged in user has purchased
    function getMyItems() public view returns (SaleItem[] memory) {
        uint256 counter = 0;
        uint256 itemCount = 0;
        uint256 length = _id.current();                

        for (uint256 i = 0; i < length; i++) {
            if (idToSaleItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        SaleItem[] memory myItems = new SaleItem[](itemCount);
        for (uint256 i = 0; i < length; i++) {
            if (idToSaleItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                SaleItem storage currentItem = idToSaleItem[
                    currentId
                ];
                myItems[counter] = currentItem;
                counter += 1;
            }
        }
        return myItems;
    }

    // get all items created in the market by the current logged in user
    function saleItemsCreated()
        public
        view
        returns (SaleItem[] memory)
    {        
        uint256 counter = 0;
        uint256 currentIndex = 0;
        uint256 length = _id.current();

        for (uint256 i = 0; i < length; i++) {
            if (idToSaleItem[i + 1].seller == msg.sender) {
                counter += 1;
            }
        }

        SaleItem[] memory saleItems = new SaleItem[](counter);
        for (uint256 i = 0; i < length; i++) {
            if (idToSaleItem[i + 1].seller == msg.sender) {
                uint256 index = i + 1;
                SaleItem storage _item = idToSaleItem[
                    index
                ];
                saleItems[currentIndex] = _item;
                currentIndex += 1;
            }
        }

        return saleItems;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecentralisedProperty {

    //contract owner
    address public contractOwner;

    //create an enumneration for custom data type
    enum PropertyStatus { Available, Pending, Sold }

    //create a structured type for information about a property to be sold
    struct propertyInfo {
        address owner;
        string name;
        string description;
        uint price;
        PropertyStatus status;
    }

    //map all available properties for sale to an address belonging to the owner
    mapping(address => propertyInfo) public properties;
    
    //map property approvals for each buyer to 1 seller (property owner). Inner mapping is for buyer, while outer mapping for seller. This is to allow property owner to approve the buyer's request.
    mapping(address => mapping(address => bool)) public sellerApproval;

    //map each verified user to an address
    mapping(address => bool) public verifiedUsers;

    //a function to log each event when a new property is added to the blockchain
    event PropertyAdded(address indexed ownerAddress, string ownerName, uint price);

    //a function to log each event when a user's identity is verified
    event IdentityVerified(address indexed user);

    //a function to log each event when a seller requested to purchase a property waiting for approval from the owner. This is to block other's from requesting on the same property
    event PropertyPending(address indexed buyer, address indexed sellerAddress, uint price);

    //a function to log each event when a property is sold
    event PropertySold(address indexed buyer, address indexed sellerAddress, uint price);



    constructor() {
        contractOwner=msg.sender;
        //verifiedUsers[msg.sender] = false; //initialization not needed as it is already false by default values
    }

    //A function to add a property to the listing, taking in 3 arguments. Property owner can call this function.
    function addProperty(string memory ownerName, string memory ownerDescription, uint askingPrice) external {
        
        //properties[msg.sender] means to access the property information from properties that is associate to the caller's address
        //associate a property info to be sold to an owner's address 
        properties[msg.sender] = propertyInfo({
            owner: msg.sender,//owner's address
            name: ownerName,//owner's name
            description: ownerDescription, //description of the property
            price: askingPrice, //asking price as demanded by owner
            status: PropertyStatus.Available //set the property status to Available
        });
        //trigger the PropertyAdded event to log successful addition of property
        emit PropertyAdded(msg.sender, ownerName, askingPrice);
    }

    //A function to verify identity of purchaser
    function verifyIdentity() external {
        //check if the user has been previously verified
        require(!verifiedUsers[msg.sender], "You are already verified");

        //Check user's mininum balance, require 50ETH to be verified
        require(address(this).balance >= 100 ether, "You need to have at least 100ETH to be a verified user");

        //Update the user to verified user
        verifiedUsers[msg.sender] = true;

        //trigger the IdentityVerified event to log successful verification
        emit IdentityVerified(msg.sender);
    }


    //A function to allow buyer to request purchase of a property, taking in arugment of the address of the owner
    function requestPurchase(address insertOwnerAddress) external payable  {
        require(verifiedUsers[msg.sender]==true, "Complete Identity Verification first before proceeding"); //only verified user can call this function
        require(properties[insertOwnerAddress].status == PropertyStatus.Available, "Property is not available for purchase"); //only available property can be requested for purchase
        require(msg.value >= properties[insertOwnerAddress].price, "Insufficient funds to complete purchase");//available fund must be greater or equals to the asking price

        //update property status to pending if request is successful
        properties[insertOwnerAddress].status = PropertyStatus.Pending; 

        //trigger the PropertyPending event
        emit PropertyPending(msg.sender, insertOwnerAddress, msg.value);
    }


    //A function to allow seller(currentOwner) to approve the purchase 
    function approvePurchase(address buyerAddress, address currentOwnerAddress) external {
        require(msg.sender == currentOwnerAddress, "You are not the property owner");//only the current owner can approve the purchase
        require(properties[currentOwnerAddress].status == PropertyStatus.Pending, "Property is not pending"); //property must be in pending i.e. requested by seller

        //after above requirements are met, this will associate the buyer's address to the seller's address, setting this to true means that the association is successful
        //outer mapping first(currentOwner), followed by inner mapping (buyer)
        sellerApproval[currentOwnerAddress][buyerAddress] = true;
    }

    //A function to allow seller to reject the purchase request by buyer
    function rejectPurchase(address buyerAddress, address sellerAddress) external {
        require(msg.sender == sellerAddress, "You are not the property owner"); //only the current owner can reject the purchase
        require(properties[sellerAddress].status == PropertyStatus.Pending, "Property is not pending");//property must be in pending i.e. requested by seller
        
        //set the sellerApproval to false
        sellerApproval[sellerAddress][buyerAddress] = false;
        //set the property status to available again
        properties[sellerAddress].status = PropertyStatus.Available;

    }

    //A function to allow buyer to confirm the purchase once approved and the funds will transferred from buyer to seller.
    function confirmPurchase(address buyerAddress, address payable sellerAddress) external {
        require(msg.sender == buyerAddress, "You are not the buyer");//only the buyer can confirm the purchase

        // Transfer funds from buyer to the seller
        sellerAddress.transfer(properties[sellerAddress].price);

        // Transfer property ownership by updating the owner's address and status
        properties[sellerAddress].owner = buyerAddress;
        //set the property status to sold
        properties[sellerAddress].status = PropertyStatus.Sold;

        //trigger the PropertySold event
        emit PropertySold(buyerAddress, sellerAddress, properties[sellerAddress].price);
    }


}
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.7.0;

contract VirtualQueue {
  // Consumer who buys a Product from the Store
  struct Consumer {
    string name;
    uint8 age;
    bool isAuthorised;
  }

  // Consumer who buys an Product from the Store
  struct Store {
    string storeName;
    address[] activeQueue;
    bool isActive;
  }

  struct Product {
    string itemName;
    uint64 price; // Save in eth
    bool isAvailable;
  }

  // Manages Stores
  address manager;

  // Waiting-list queue
  address[] public waitingQueue;

  // General Store Items
  mapping(uint32 => Product) public products;
  uint32 totalProducts = 0;

  // Registered Stores by the Manager
  mapping(address => Store) public stores;
  uint32 totalStores = 0;

  // Actions ONLY Managers can perform:
  // registerStore, addItem, removeItem
  modifier onlyManager() {
    require(
      manager == msg.sender,
      "Only Manager is allowed to do this operation!"
    );
    _;
  }

  // Deploy with Manager's Address
  constructor(address _manager) public {
    manager = _manager;
  }

  // Add new Product to the Store
  function addProduct(string memory _productName, uint64 _productPrice) public onlyManager {
    products[totalProducts] = Product(
      _productName,
      _productPrice * 1 ether,
      true
    );
    totalProducts += 1;
  }

  // Deletes Product at index
  function disabledProduct(uint32 index) public onlyManager {
    products[index].isAvailable = false;
  }

  // Register new Store for Manager
  function registerStore(address _store, string memory _storeName) public onlyManager {
    // Do nothing if Store is Available
    if (stores[_store].isActive) return;
    stores[_store] = Store(
      _storeName,
      new address[](0),
      true
    );
    totalStores += 1;
  }

}
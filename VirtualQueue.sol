// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.7.0;

contract VirtualQueue {
  // Consumer who buys an item from the Store
  struct Consumer {
    string name;
    uint age;
    bool isAuthorised;
  }

  // Consumer who buys an item from the Store
  struct Store {
    string storeName;
    string[] items;
    address[] activeQueue;
  }

  // Manages Stores
  address manager;

  // Waiting-list queue
  address[] public waitingQueue;

  // General Store Items
  string[] public items = ["Whisky", "Brandy", "Rum"];

  // Registered Stores by the Manager
  mapping(address => Store) public stores;

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

  // Add new item to the Store
  function addItem(string memory item) public onlyManager {
    items.push(item);
  }

  // Deletes item at index
  function addItem(uint index) public onlyManager {
    delete items[index];
  }

  // Register new Store for Manager
  function registerStore(address store, string memory _storeName) public onlyManager {
    stores[store] = Store(_storeName, items, new address[](0));
  }

}
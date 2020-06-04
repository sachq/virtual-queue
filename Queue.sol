// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.7.0;

contract Queue {
	mapping(uint256 => address) queue;
	uint256 first = 1;
	uint256 last = 0;

	function enqueue(address data) external {
		last += 1;
		queue[last] = data;
	}

	function dequeue() external returns (address data) {
		require(last >= first, "Queue is Empty");
		data = queue[first];
		delete queue[first];
		first += 1;
	}
}
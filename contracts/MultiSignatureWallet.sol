pragma solidity ^0.4.15;

contract MultiSignatureWallet {

    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event TestExec(uint indexed transactionId);

    struct Transaction {
	  bool executed;
      address destination;
      uint value;
      bytes data;
    }

    ///Since we are going to keep ownerCount and required for the life of the contract, we need to declare the variables in storage in order to save them
    address[] public owners;
    uint public required;
    mapping(address => bool) public isOwner;
    mapping(uint => Transaction) public transactions;
    uint public transactionCount;
    mapping(uint => mapping(address => bool)) public confirmations;

    /// @dev Fallback function, which accepts ether when sent to contract
    function() public payable {}

    //add modifier
    modifier validRequirements(uint ownerCount, uint _required) {
        if (_required > ownerCount || ownerCount == 0 || _required == 0) {
            revert();
        }
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor (address[] _owners, uint _required) public validRequirements(_owners.length, _required) {
        for(uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes data) public returns (uint transactionId) {
        require(isOwner[msg.sender]); //this function is callable only by an owner
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
        require(isOwner[msg.sender]); //only wallet owner should call the function
        require(transactions[transactionId].destination != 0); //check if transaction id exist at the given destination
        require(confirmations[transactionId][msg.sender] == false); //verify that the owner haasn't confirmed the transaction before
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {}

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false); //verify that the transaction hasn't been executed before
        if (isConfirmed(transactionId)) {
            Transaction tx = transactions[transactionId];
            tx.executed = true;
            if (tx.destination.call.value(tx.value)(tx.data))
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                tx.executed = false;
            }
        }
    }
		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal constant returns (bool) {
        uint count = 0;
        for (uint i = 0; i<owners.length; i++) {
            if (confirmations[transactionId][owners[i]])
                count += 1;
            if (count == required)
                return true;
        }
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionId += 1;
        emit Submission(transactionId);
    }
}

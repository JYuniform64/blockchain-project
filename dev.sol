pragma solidity ^0.4.22;

contract Supply {
    enum e_ApproveStatus { WaittingDebtee, WaittingBank, Approved, Disapproved, WaittingTransfer, Loaned }
    enum e_ReceiptStatus { Valid, Invalid }
    struct Receipt {
        uint amount;
        address debtor;
        address debtee;
        uint start_time;
        uint duration;
        string remark;
        e_ApproveStatus approval;
        e_ReceiptStatus status;
    }

    address public bank;
    mapping(uint => Receipt) receipts;
    uint receipt_num;
    mapping(address => uint) reputations;
    address[] enterprises;

    constructor() public {
        bank = msg.sender;
        receipt_num = 0;
    }

    function register() public returns (bool success) {
        require(msg.sender != bank, "No need for register");
        bool need_register = true;
        for(uint i = 0; i < enterprises.length; i++) {
            if(msg.sender == enterprises[i]) {
                need_register = false;
                break;
            }
        }
        if(need_register) {
            enterprises.push(msg.sender)
            return true;
        } else 
            return false;
    }
    
    function set_reputation(address user, uint value) public returns (bool success) {
        require(msg.sender == bank, "No privilege");
        if (value <=0 || value >= 100)
            return false;
        reputations[user] = value;
        return true;
    }
    
    //whether necessary?
    function get_reputation(address user) public returns (uint value) {
        return reputations[user];
    }

    function limit_amount_by_reputation(uint reputation) public returns (uint amount) {
        //reputation range[0,100]
        //[81,100]: 一千一百万 - 一亿一千一百万
        //[61,80 ]: 一百万 - 一千一百万
        //[11,60 ]: <一百万
        if(reputation <= 10) return 0;
        else if(reputation > 10 && reputation <= 60) return 20000 * (reputation - 10);
        else if(reputation > 60 && reputation <= 80) return 1000000 + (reputation - 60) * 500000; 
        else if(reputation > 80 && reputation <= 100) return 11000000 + (reputation - 80) * 5000000;
    }

    function enough_reputation(address user, uint amount) public returns (bool) {
        if(reputations[user] < amount) return false;
        else return true;
    }
    
    function purchase(address debtee, uint amount, uint duration, string remark) public returns (uint index) {
        require(msg.sender != bank, "No privilege");
        Receipt memory receipt = Receipt(
            amount, 
            msg.sender, 
            debtee, 
            now, 
            duration, 
            remark, 
            e_ApproveStatus.WaittingDebtee, 
            e_ReceiptStatus.Invalid
        );
        receipts[receipt_num] = receipt;
        receipt_num++;
        return receipt_num - 1;
    }

    function accept_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].start_time + receipts[indexOfReceipt].duration > now, "Time expired");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.WaittingDebtee, "Invalid approval status");

        receipts[indexOfReceipt].approval = e_ApprovalStatus.WaittingBank;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    function reject_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.WaittingDebtee, "Invalid approval status");

        receipts[indexOfReceipt].approval = e_ApprovalStatus.Disapproved;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    function approve_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].start_time + receipts[indexOfReceipt].duration > now, "Time expired");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.waittingBank &&
            receipts[indexOfReceipt].status == e_ReceiptStatus.Invalid, "Invalid approval status");
        require(enough_reputation(receipts[indexOfReceipt].debtor, receipts[indexOfReceipt].amount), "No enough reputation");

        receipts[indexOfReceipt].approval = e_ApprovalStatus.Approved;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Valid;
    }

    function disapprove_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.waittingBank &&
            receipts[indexOfReceipt].status == e_ReceiptStatus.Invalid, "Invalid approval status");

        receipts[indexOfReceipt].approval = e_ApprovalStatus.Disapproved;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    function transfer_receipt(address debtee, uint indexOfReceipt, uint amount, string remark) public returns (uint indexOfOriginReceipt, uint indexOfNewReceipt) {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].status == e_ReceiptStatus.Valid && 
            receipts[indexOfReceipt].approval == e_ApproveStatus.Approved, "Invalid status");
        require(receipts[indexOfReceipt].start_time + receipts[indexOfReceipt].duration > now, "Time expired");
        require(receipts[indexOfReceipt].amount >= amount, "Insufficient funds");
        
        indexOfNewReceipt = receipt_num;
        indexOfOriginReceipt = indexOfReceipt;

        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
        receipts[indexOfReceipt].amount -= amount;
        Receipt memory receipt = Receipt(
            amount,
            receipts[indexOfReceipt].debtor,
            debtee,
            receipts[indexOfReceipt].start_time,
            receipts[indexOfReceipt].duration,
            remark
            e_ApproveStatus.WaittingTransfer,
            e_ReceiptStatus.Invalid
        );  
        receipts[receipt_num] = receipt;
        receipt_num++;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Valid;
        return;
    }

    function from_same_receipt(uint index1, uint index2) public returns (bool) {
        //assume both indexs are valid.
        if(receipts[index1].debtor == receipt[index2].debtor && 
            receipts[index1].start_time == receipt[index2].start_time &&
            receipts[index1].duration == receipt[index2].duration) return true;
        else return false;
    }
    
    function accept_transfer(uint indexOfOriginReceipt, uint indexOfNewReceipt) public {
        require(indexOfReceipt < receipt_num && indexOfOriginReceipt < receipt_num, "Invalid index");
        require(from_same_receipt(indexOfOriginReceipt, indexOfNewReceipt), "Not from same receipt");
        require(msg.sender == receipts[indexOfNewReceipt].debtee, "No privilege");
        require(receipts[indexOfNewReceipt].status == e_ReceiptStatus.Invalid && 
            receipts[indexOfNewReceipt].approval == e_ApproveStatus.WaittingTransfer, "Invalid status");
        require(receipts[indexOfNewReceipt].start_time + receipts[indexOfNewReceipt].duration > now, "Time expired");

        receipts[indexOfNewReceipt].approval = e_ApproveStatus.Approved;
        receipts[indexOfNewReceipt].status = e_ReceiptStatus.Valid;
    }

    function reject_transfer(uint indexOfOriginReceipt, uint indexOfNewReceipt) public {
        //return the money in new receipt back to the origin receipt
        require(indexOfReceipt < receipt_num && indexOfOriginReceipt < receipt_num, "Invalid index");
        require(from_same_receipt(indexOfOriginReceipt, indexOfNewReceipt), "Not from same receipt");
        require(msg.sender == receipts[indexOfNewReceipt].debtee, "No privilege");
        require(receipts[indexOfNewReceipt].status == e_ReceiptStatus.Invalid && 
            receipts[indexOfNewReceipt].approval == e_ApproveStatus.WaittingTransfer, "Invalid status");
        
        receipts[indexOfNewReceipt].approval = e_ApproveStatus.Disapproved;
        receipts[indexOfNewReceipt].status = e_ReceiptStatus.Invalid;
        receipts[indexOfOriginReceipt].status = e_ReceiptStatus.Invalid;
        receipts[indexOfOriginReceipt].amount += receipts[indexOfNewReceipt].amount;
        receipts[indexOfOriginReceipt].status = e_ReceiptStatus.Valid;
    }

    function loan(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == bank, "No privilege");
        require(receipts[indexOfReceipt].status == e_ReceiptStatus.Valid && 
            receipts[indexOfReceipt].approval == e_ApproveStatus.Approved, "Invalid status");
        require(receipts[indexOfReceipt].start_time + receipts[indexOfReceipt].duration > now, "Time expired");

        receipts[indexOfReceipt].approval = e_ApproveStatus.Loaned;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    function destoryReceipt(uint indexOfReceipt) public returns (bool success) {
        //Todo: what to do when time expired
        require(indexOfReceipt < receipt_num, "Invalid index");
        if(receipts[indexOfReceipt].approval == e_ApproveStatus.Loaned) {
            require(msg.sender == bank, "No privilege");
            receipts[indexOfReceipt].approval = e_ApproveStatus.Approved;
            receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
            return true;
        }
        if(receipts[indexOfReceipt].approval == e_ApproveStatus.Approved) {
            require(receipts[indexOfReceipt].status = e_ReceiptStatus.Valid, "Invalid status");
            require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
            receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
            return true;
        }
        return false;
    }

}
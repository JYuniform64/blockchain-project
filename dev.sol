pragma solidity ^0.4.22;

contract Supply {
    enum e_ApproveStatus { WaittingDebtee, WaittingBank, Approved, Disapproved, WaittingTransfer, Loaned }
    enum e_ReceiptStatus { Valid, Invalid }
    struct Receipt {
        uint amount;        //金额
        address debtor;     //债务人
        address debtee;     //债权人
        uint start_time;        //单据签订时间
        uint duration;      //债务有效期
        string remark;      //单据备注
        e_ApproveStatus approval;       //单据当前审批状态
        e_ReceiptStatus status;     //单据当前是否可用于交易
    }

    address public bank;        //第三方机构（银行）
    mapping(uint => Receipt) receipts;      //由序号索引的单据
    uint receipt_num;       //总单据数量
    mapping(address => uint) reputations;       //企业信誉度
    address[] enterprises;      //已向第三方注册的企业

    constructor() public {
        bank = msg.sender;
        receipt_num = 0;
    }

    //企业向第三方信用机构注册自己
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
            enterprises.push(msg.sender);
            return true;
        } else 
            return false;
    }

    //第三方信用机构对企业的信用进行评级
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

    //信用度对应的最大应收账款单据额度
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

    //判断企业的信用度是否足够使第三方信用机构同意由其发起的应收账款单据
    function enough_reputation(address user, uint amount) public returns (bool) {
        if(reputations[user] < amount) return false;
        else return true;
    }
    
    //企业debtor向企业debtee发起签署应收账款单据
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

    //企业debtee同意企业debtor发起的应收账款单据
    function accept_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].start_time + receipts[indexOfReceipt].duration > now, "Time expired");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.WaittingDebtee, "Invalid approval status");

        receipts[indexOfReceipt].approval = e_ApproveStatus.WaittingBank;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    //企业debtee拒绝企业debtor发起的应收账款单据
    function reject_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.WaittingDebtee, "Invalid approval status");

        receipts[indexOfReceipt].approval = e_ApproveStatus.Disapproved;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    //第三方信用机构批准由企业debtor发起，经企业debtee同意的应收账款单据
    function approve_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].start_time + receipts[indexOfReceipt].duration > now, "Time expired");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.WaittingBank &&
            receipts[indexOfReceipt].status == e_ReceiptStatus.Invalid, "Invalid approval status");
        require(enough_reputation(receipts[indexOfReceipt].debtor, receipts[indexOfReceipt].amount), "No enough reputation");

        receipts[indexOfReceipt].approval = e_ApproveStatus.Approved;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Valid;
    }

    //第三方信用机构拒绝由企业debtor发起，经企业debtee同意的应收账款单据
    function disapprove_purchase(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
        require(receipts[indexOfReceipt].approval == e_ApproveStatus.WaittingBank &&
            receipts[indexOfReceipt].status == e_ReceiptStatus.Invalid, "Invalid approval status");

        receipts[indexOfReceipt].approval = e_ApproveStatus.Disapproved;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    //应收账款单据的debtee向一个新的企业转让其持有的应收账款单据的部分或全部额度
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
            remark,
            e_ApproveStatus.WaittingTransfer,
            e_ReceiptStatus.Invalid
        );  
        receipts[receipt_num] = receipt;
        receipt_num++;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Valid;
        return;
    }

    //检查两个应收账款单据是否同源
    function from_same_receipt(uint index1, uint index2) public returns (bool) {
        //assume both indexs are valid.
        if(receipts[index1].debtor == receipts[index2].debtor && 
            receipts[index1].start_time == receipts[index2].start_time &&
            receipts[index1].duration == receipts[index2].duration) return true;
        else return false;
    }
    
    //新的企业同意应收账款单据的转让
    function accept_transfer(uint indexOfOriginReceipt, uint indexOfNewReceipt) public {
        require(indexOfNewReceipt < receipt_num && indexOfOriginReceipt < receipt_num, "Invalid index");
        require(from_same_receipt(indexOfOriginReceipt, indexOfNewReceipt), "Not from same receipt");
        require(msg.sender == receipts[indexOfNewReceipt].debtee, "No privilege");
        require(receipts[indexOfNewReceipt].status == e_ReceiptStatus.Invalid && 
            receipts[indexOfNewReceipt].approval == e_ApproveStatus.WaittingTransfer, "Invalid status");
        require(receipts[indexOfNewReceipt].start_time + receipts[indexOfNewReceipt].duration > now, "Time expired");

        receipts[indexOfNewReceipt].approval = e_ApproveStatus.Approved;
        receipts[indexOfNewReceipt].status = e_ReceiptStatus.Valid;

        if(receipts[indexOfOriginReceipt].amount == 0)
            receipts[indexOfOriginReceipt].status = e_ReceiptStatus.Invalid;
    }

    //新的企业拒绝应收账款单据的转让
    function reject_transfer(uint indexOfOriginReceipt, uint indexOfNewReceipt) public {
        //return the money in new receipt back to the origin receipt
        require(indexOfNewReceipt < receipt_num && indexOfOriginReceipt < receipt_num, "Invalid index");
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

    //企业依据其持有的应收账款单据向银行贷款
    function loan(uint indexOfReceipt) public {
        require(indexOfReceipt < receipt_num, "Invalid index");
        require(msg.sender == bank, "No privilege");
        require(receipts[indexOfReceipt].status == e_ReceiptStatus.Valid && 
            receipts[indexOfReceipt].approval == e_ApproveStatus.Approved, "Invalid status");
        require(receipts[indexOfReceipt].start_time + receipts[indexOfReceipt].duration > now, "Time expired");

        receipts[indexOfReceipt].approval = e_ApproveStatus.Loaned;
        receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
    }

    //在应收账款单据的债务人缴清费用后删除该单据
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
            require(receipts[indexOfReceipt].status == e_ReceiptStatus.Valid, "Invalid status");
            require(msg.sender == receipts[indexOfReceipt].debtee, "No privilege");
            receipts[indexOfReceipt].status = e_ReceiptStatus.Invalid;
            return true;
        }
        return false;
    }

}

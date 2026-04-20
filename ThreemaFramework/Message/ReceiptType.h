#ifndef ReceiptType_h
#define ReceiptType_h

typedef NS_CLOSED_ENUM(uint8_t, ReceiptType) {
    ReceiptTypeReceived = DELIVERYRECEIPT_MSGRECEIVED,
    ReceiptTypeRead = DELIVERYRECEIPT_MSGREAD,
    ReceiptTypeAck = DELIVERYRECEIPT_MSGUSERACK,
    ReceiptTypeDecline = DELIVERYRECEIPT_MSGUSERDECLINE,
    ReceiptTypeConsumed = DELIVERYRECEIPT_MSGCONSUMED
};

#endif /* ReceiptType_h */

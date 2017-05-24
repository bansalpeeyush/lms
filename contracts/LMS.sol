pragma solidity ^0.4.0;

import "./strings.sol";
import "./StringLib.sol";
import "zeppelin/lifecycle/Killable.sol";

contract LMS is Killable {
    // In order to use the third-party strings library
    using strings for *;

    enum State {
        Available,
        Borrowed,
        Overdue,
        Lost,
        Removed
    }

    enum MemberStatus { Active, Inactive }

    struct Book {
        uint id;
        string title;
        string author;
        string publisher;
        address owner;
        address borrower;
        State state;
        uint dateAdded;
        uint dateIssued;
        string imgUrl;
        string description;
        string genre;
        uint avgRating;
        uint totalRating;
        uint reviewersCount;
    }

    struct Member {
        string name;
        address account;
        string email;
        MemberStatus status;
        uint dateAdded;
        string location;
    }

    uint public numBooks;
    uint public numMembers;
    mapping (uint => Book) catalog;                 // index 0 to be kept free since 0 is default value
    mapping (uint => Member) members;               // index 0 to be kept free since 0 is default value
    mapping (address => uint) memberIndex;
    mapping (string => uint) emailIndex;

    event Borrow(uint indexed bookId, address indexed borrower, uint timestamp);
    event Return(uint indexed bookId, address indexed borrower, uint timestamp);
    event Rate(uint indexed bookId, address indexed reviewer, uint indexed rating, string comments, uint timestamp);

    modifier onlyMember {
        bool member = false;
        for (uint i=1; i <= numMembers; i++) {
            if (msg.sender == members[i].account && members[i].status == MemberStatus.Active) {
                member = true;
                break;
            }
        }
        if (!member) {
            throw;
        } else {
            _;
        }
    }

    function LMS(string name, string email, string location) payable {
        // Owner is the first member of our library, at index 1 (NOT 0)
        // location: member location, help in geo separation.
        members[++numMembers] = Member(name, owner, email, MemberStatus.Active, now, location);
        memberIndex[owner] = numMembers;
        emailIndex[email] = numMembers;
    }

    function addMember(string name, address account, string email, string location) public onlyOwner {
        // Add or activate member
        var index = memberIndex[account];
        // TODO Check if the email is different for the same account hash. Return addMember failure with error as
        // duplicate member. If the email is same, then change the memberstatus as active.
        // Also, write tests for it.
        if (index != 0) {           // This is the reason index 0 is not used
            members[index].status = MemberStatus.Active;
            return;
        }
        members[++numMembers] = Member(name, account, email, MemberStatus.Active, now, location);
        memberIndex[account] = numMembers;
        emailIndex[email] = numMembers;
    }

    function getMemberDetailsByEmail(string email) constant returns (string, address, string, MemberStatus, uint, string) {
        var i = emailIndex[email];
        if(i != 0) {
            return (members[i].name, members[i].account, members[i].email, members[i].status, members[i].dateAdded, members[i].location);
        }
    }

    function removeMember(address account) public onlyOwner {
        // Deactivate member
        var index = memberIndex[account];
        if (index != 0) {
            members[index].status = MemberStatus.Inactive;
        }
    }

    function getOwnerDetails() constant returns (string, address, string, MemberStatus, uint, string) {
        return getMemberDetailsByAccount(owner);
    }

    function getMemberDetailsByAccount(address account) constant returns (string, address, string, MemberStatus, uint, string) {
        var i = memberIndex[account];
        if(i != 0) {
            return (members[i].name, members[i].account, members[i].email, members[i].status, members[i].dateAdded, members[i].location);
        }
    }

    function getMemberDetailsByIndex(uint i) constant returns (string memberString) {
        if (i < 1 || i > numMembers) {
            throw;
        }
        var parts = new strings.slice[](5);
        //Iterate over the entire catalog to find my books
        parts[0] = members[i].name.toSlice();
        parts[1] = StringLib.addressToString(members[i].account).toSlice();
        parts[2] = members[i].email.toSlice();
        parts[3] = StringLib.uintToString(uint(members[i].status)).toSlice();
        parts[4] = StringLib.uintToString(members[i].dateAdded).toSlice();
        memberString = ";".toSlice().join(parts);
    }

    function getAllMembers() constant onlyMember returns (string memberString, uint8 count) {
        string memory member;
        for (uint i = 1; i <= numMembers; i++) {
            member = getMemberDetailsByIndex(i);
            count++;
            if (memberString.toSlice().equals("".toSlice())) {
                memberString = member;
            } else {
                memberString = memberString.toSlice().concat('|'.toSlice()).toSlice().concat(member.toSlice());
            }
        }
    }

    function addBook(string title, string author, string publisher, string imgUrl, string description, string genre) public onlyMember {
        ++numBooks;
        catalog[numBooks] = Book({
            id: numBooks,
            title: title,
            publisher: publisher,
            author: author,
            borrower: 0x0,
            owner: msg.sender,
            state: State.Available,
            dateAdded: now,
            dateIssued: 0,
            imgUrl: imgUrl,
            description: description,
            genre: genre,
            avgRating: 0,
            reviewersCount: 0,
            totalRating: 0
        });
        if (this.balance < 10**12) {
            throw;
        }
        if(!catalog[numBooks].owner.send(10**12)) {
            throw;
        }
    }

    function updateBook(uint i, string title, string author, string publisher, string imgUrl, string description, string genre) public onlyMember {
        if(i <= numBooks && catalog[i].owner == msg.sender) {
            catalog[i].title = title;
            catalog[i].author = author;
            catalog[i].publisher = publisher;
            catalog[i].imgUrl = imgUrl;
            catalog[i].description = description;
            catalog[i].genre = genre;
            catalog[i].state = State.Available;
        }
    }

    function getBook(uint i) constant returns (string bookString) {
        if (i < 1 || i > numBooks) {
            throw;
        }
        var parts = new strings.slice[](15);
        //Iterate over the entire catalog to find my books
        parts[0] = StringLib.uintToString(catalog[i].id).toSlice();
        parts[1] = catalog[i].title.toSlice();
        parts[2] = catalog[i].author.toSlice();
        parts[3] = catalog[i].publisher.toSlice();
        parts[4] = StringLib.addressToString(catalog[i].owner).toSlice();
        parts[5] = StringLib.addressToString(catalog[i].borrower).toSlice();
        parts[6] = StringLib.uintToString(uint(catalog[i].state)).toSlice();
        parts[7] = StringLib.uintToString(catalog[i].dateAdded).toSlice();
        parts[8] = StringLib.uintToString(catalog[i].dateIssued).toSlice();
        parts[9] = catalog[i].imgUrl.toSlice();
        parts[10] = catalog[i].description.toSlice();
        parts[11] = catalog[i].genre.toSlice();
        parts[12] = StringLib.uintToString(catalog[i].avgRating).toSlice();
        parts[13] = StringLib.uintToString(catalog[i].totalRating).toSlice();
        parts[14] = StringLib.uintToString(catalog[i].reviewersCount).toSlice();
        bookString = ";".toSlice().join(parts);
    }

    function getBooks(bool ownerFilter) constant onlyMember returns (string bookString, uint8 count) {
        string memory book;
        //Iterate over the entire catalog to find my books
        for (uint i = 1; i <= numBooks; i++) {
            if (!ownerFilter || catalog[i].owner == msg.sender || catalog[i].borrower == msg.sender) {
                book = getBook(i);
                count++;
                if (bookString.toSlice().equals("".toSlice())) {
                    bookString = book;
                } else {
                    bookString = bookString.toSlice().concat('|'.toSlice()).toSlice().concat(book.toSlice());
                }
            }
        }
    }

    function getMyBooks() constant onlyMember returns (string bookString, uint8 count) {
        return getBooks(true);
    }

    function getAllBooks() constant onlyMember returns (string bookString, uint8 count) {
        return getBooks(false);
    }

    function getMyLocationBooks() constant onlyMember returns (string bookString, uint8 count) {
        string memory book;
        string memory memberLocation;
    
        //get the location of the msg.sender
        var loc = members[memberIndex[msg.sender]].location;

        //Iterate over books in the catalog 
        //get the member index of the owner of the book
        //check if location of msg.sender is same as owner of the book
        for(uint i = 1; i <= numBooks; i++) {
            memberLocation = members[memberIndex[catalog[i].owner]].location;
            if(loc.toSlice().equals(memberLocation.toSlice())) {
                book = getBook(i);
                count++;
                if (bookString.toSlice().equals("".toSlice())) {
                    bookString = book;
                } else {
                    bookString = bookString.toSlice().concat('|'.toSlice()).toSlice().concat(book.toSlice());
                }
            }
        }
    }

    function borrowBook(uint id) onlyMember payable {
        // Can't borrow book if passed value is not sufficient
        if (msg.value < 10**12) {
            throw;
        }
        // Can't borrow a non-existent book
        if (id > numBooks || catalog[id].state != State.Available) {
            throw;
        }
        catalog[id].borrower = msg.sender;
        catalog[id].dateIssued = now;
        catalog[id].state = State.Borrowed;
        // 50% value is shared with the owner
        var owner_share = msg.value/2; 
        if (!catalog[id].owner.send(owner_share)) {
            throw;
        }
        Borrow(id, msg.sender, catalog[id].dateIssued);
    }

    function returnBook(uint id) onlyMember {
        address borrower;
        if (id > numBooks || catalog[id].state == State.Available || catalog[id].owner != msg.sender) {
            throw;
        }
        borrower = catalog[id].borrower;
        catalog[id].borrower = 0x0;
        catalog[id].dateIssued = 0;
        catalog[id].state = State.Available;
        Return(id, borrower, now);
    }

    function rateBook(uint id, uint rating, string comments, uint oldRating) onlyMember {
        if (id > numBooks || rating < 1 || rating > 5) {
            throw;
        }
        uint change = rating - oldRating;
        if (oldRating == 0) {
            catalog[id].reviewersCount += 1;
            catalog[id].totalRating += change;
            catalog[id].avgRating = catalog[id].totalRating / catalog[id].reviewersCount;
        }
        else {
            catalog[id].totalRating += change;
            catalog[id].avgRating = catalog[id].totalRating / catalog[id].reviewersCount;
        }

        // All reviews are logged. Applications are responsible for eliminating duplicate ratings
        // and computing average rating.
        Rate(id, msg.sender, rating, comments, now);
    }
}

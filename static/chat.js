function setUpChat() {
    $('#chatSubmit').click(sendChat);
    
    $('#chatLine').keypress(function (e) {
        if (e.keyCode == 13) 
            sendChat();
    });
}

function getChatLine(text) {
    appendChatLine("Other guy", text);
}

function appendChatLine(user, text) {
    var newP = $('<p></p>');
    newP.append($('<span></span').text(user).css("font-weight","bold").css('padding-right','10px'));
    newP.append($('<span></span').text(text));

    newP.addClass("chatLineP");

    $('#chatLog').append(newP);
    
    //Scrolls to the bottom of chatLog div
    //Thanks, http://kisdigital.wordpress.com/2010/03/10/using-jquery-to-scroll-to-the-bottom-of-a-div-revised/#comments
    $("#chatLog").animate({ scrollTop: $("#chatLog").attr("scrollHeight") - $('#chatLog').height() }, 500);
}

function sendChat() {
    var chatLine = $('#chatLine').val();
    
    if (chatLine == "") return;

    $("#content").get()[0].chatSend(chatLine);
    
    appendChatLine("Me", chatLine);
    
    $('#chatLine').val('');
    $('#chatLine').focus();
}

function clearChat() {
    $('.chatLineP').remove();
}
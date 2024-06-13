class P2PConstraints {
  static const Map<String, dynamic> MEDIA_CONSTRAINTS = {
    "audio": true,
    "video": {
      "mandatory": {
        "minWidth": "640",
        "minHeight": "480",
        "minFrameRate": "30"
      },
      "facingMode": "user",
      "optional": []
    }
  };

  static const Map<String, dynamic> SDP_CONSTRAINTS = {
    "mandatory": {"OfferToReceiveAudio": true, "OfferToReceiveVideo": true},
    "optional": []
  };

  
}

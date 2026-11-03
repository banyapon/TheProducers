// Google Identity Services owns the Google button and account popup.
// Firebase verifies the returned ID token through signInWithIdp.
if (!window.producerGoogle) {
  window.producerGoogle = {
    result: null,
    close() {
      document.getElementById('producer-google-modal')?.remove();
      this.result = null;
    },
    open(clientId) {
      this.close();
      const modal = document.createElement('div');
      modal.id = 'producer-google-modal';
      modal.style.cssText = 'position:fixed;inset:0;z-index:99999;background:#000a;display:grid;place-items:center';
      const card = document.createElement('div');
      card.style.cssText = 'background:#121e31;color:white;padding:32px;border:2px solid #ffd166;font:20px sans-serif;text-align:center';
      const title = document.createElement('p');
      title.textContent = 'Connect with Google';
      const button = document.createElement('div');
      const cancel = document.createElement('button');
      cancel.textContent = 'Cancel';
      cancel.style.cssText = 'margin-top:24px;padding:12px 32px;font-size:18px';
      cancel.onclick = () => { this.result = {error: 'cancelled'}; };
      card.append(title, button, cancel);
      modal.append(card);
      document.body.append(modal);
      const render = () => {
        if (!modal.isConnected) return;
        google.accounts.id.initialize({client_id: clientId, ux_mode: 'popup', auto_select: false,
          callback: response => {
            if (modal.isConnected) this.result = {id_token: response.credential, redirect_uri: location.origin};
          }
        });
        google.accounts.id.renderButton(button, {type:'standard', theme:'outline', size:'large', text:'continue_with', width:300});
      };
      if (window.google?.accounts?.id) render();
      else {
        let script = document.getElementById('producer-google-sdk');
        if (!script) {
          script = document.createElement('script');
          script.id = 'producer-google-sdk';
          script.src = 'https://accounts.google.com/gsi/client';
          script.async = true;
          document.head.append(script);
        }
        script.addEventListener('load', render, {once:true});
        script.addEventListener('error', () => { this.result = {error:'browser'}; script.remove(); }, {once:true});
      }
    }
  };
}

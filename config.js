/* =====================================================================
   CONFIGURAÇÃO DO FUNIL — usada pelo index.html e pelo obrigado.html
   ===================================================================== */
window.CONFIG = {
  marca: "Avalia Barretos",
  whatsapp: "5517992623594",          // seu WhatsApp com DDI+DDD, só números
  email: "eduhtoledo@gmail.com",
  empresaRodape: "Avalia Barretos · Barretos/SP",
  // preço de cada kit (R$). O "Economize X%" e o "cada placa sai por" são calculados sozinhos.
  // Links: cole o link "embed" de cada produto da GGcheckout
  // (formato https://ggcheckout.app/checkout/embed/XXXX — o mesmo do href do botão que a GG gera).
  // Mesmo link para as duas cores. Para separar por cor, use link: { azul: "...", preta: "..." }.
  kits: [
    { qtd: 1,  preco: 59.00,  badge: "",               desc: "Ideal para começar",
      link: "https://ggcheckout.app/checkout/embed/576J065gGrRNBPlPydrrzY" },
    { qtd: 3,  preco: 139.90, badge: "",               desc: "Para pequenos negócios",
      link: "https://ggcheckout.app/checkout/embed/Uz89I2kKR5nAw4czuIRqa3" },
    { qtd: 5,  preco: 229.90, badge: "Mais escolhido", desc: "Para negócios em crescimento",
      link: "https://ggcheckout.app/checkout/embed/KzpmCQj0osE8iGnAB47mpg" },
    { qtd: 10, preco: 399.90, badge: "Melhor custo",   desc: "Para negócios movimentados",
      link: "https://ggcheckout.app/checkout/embed/WsRTVWxWy6CIeVGJm1RwOP" }
  ]
};

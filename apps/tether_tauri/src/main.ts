import { createApp } from "vue";
import { createPinia } from "pinia";
import App from "./App.vue";
import "./styles.css";
import { applyTheme, initialTheme } from "./core/theme";

applyTheme(initialTheme());

createApp(App).use(createPinia()).mount("#app");

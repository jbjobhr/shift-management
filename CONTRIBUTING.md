# 開發貢獻指南

## 前端

### 啟動

1. **使用 VS Code Live Server（推薦）**

   ```bash
   # 安裝 Live Server 擴充套件後，右鍵點擊 index.html 選擇「Open with Live Server」
   ```

2. **使用 Python HTTP Server**

   ```bash
   cd shift-management
   python -m http.server 8080
   # 瀏覽器開啟 http://localhost:8080
   ```

3. **使用 Node.js http-server**
   ```bash
   npx http-server -p 8080
   # 瀏覽器開啟 http://localhost:8080
   ```
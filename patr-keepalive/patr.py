import os
import time
from playwright.sync_api import Playwright, sync_playwright, expect

# 使用环境变量，并预留本地调试接口
try:
    username = os.environ['PATR_USERNAME']
except:
    username = "misaka"

try:
    password = os.environ['PATR_PASSWORD']
except:
    password = "misaka123"

def run(playwright: Playwright) -> None:
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()
    page.goto("https://app.patr.cloud/login")
    page.get_by_placeholder("Username/Email").click()
    page.get_by_placeholder("Username/Email").fill(username)
    page.get_by_placeholder("Password").click()
    page.get_by_placeholder("Password").fill(password)
    page.screenshot(path=f'result1.png')
    # 预留20s，以等待页面缓冲
    time.sleep(20)
    page.get_by_role("button", name="LOGIN").click()
    time.sleep(20)
    page.screenshot(path=f'result2.png')
    # 预留30s，以进入控制台首页
    time.sleep(30)
    page.goto("https://app.patr.cloud/")
    page.screenshot(path=f'result3.png')
    page.get_by_role("button", name="Infrastructure Infrastructure").click()
    page.get_by_role("button", name="VIEW DEPLOYMENTS").click()
    page.get_by_role("button", name="MANAGE DEPLOYMENT").click()
    page.screenshot(path=f'result4.png')
    page.get_by_role("button", name="STOP").click()
    time.sleep(60)
    page.screenshot(path=f'result5.png')
    page.get_by_role("button", name="START").click()
    page.screenshot(path=f'result6.png')
    time.sleep(60)

    # ---------------------
    context.close()
    browser.close()


with sync_playwright() as playwright:
    run(playwright)
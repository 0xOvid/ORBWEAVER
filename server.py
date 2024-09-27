# Server to send commands and recive screenshots

from flask import Flask, render_template, request, jsonify, flash, redirect, url_for, send_file
from flask_assets import Bundle, Environment
import json
import datetime
from dataclasses import dataclass
import time
import random
import os


app = Flask(__name__)
assets = Environment(app)
# Reciving screenshot from agent
UPLOAD_FOLDER = './static'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Global variables
# Queue info: timestamp, executed, command
@dataclass
class queue_item:
    uid: int
    timestamp: str
    executed: bool
    command: str


queue = []
# for some reason an int does not work
last_callback = [0]


@app.route("/")
def homepage():
    return render_template("index.html")

@app.route("/send_click", methods=['POST']) 
def send_click():
    data = request.json
    print(data)
    x = data[1]["relative_x"]
    y = data[1]["relative_y"]
    # Calculate mouse location from relative paths
    # we are using MOUSEEVENTF_ABSOLUTE so everything is a relative value of 65535
    # https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-mouseinput
    action = data[0]
    cmd = {
        "mouse": {
            "x": round(65535 * (x / 100)),
            "y": round(65535 * (y / 100)),
            "action": action
        },
        "keystrokes": ""
    }
    
    q_cmd = queue_item(
        len(queue),
        str(datetime.datetime.utcfromtimestamp(time.time())),
        False,
        cmd
    )
    queue.append(q_cmd)
    return ""

@app.route("/send_text", methods=['POST']) 
def send_text():
    data = request.form
    cmd = {
        "mouse": {
            "x": 0,
            "y": 0,
            "action": ""
        },
        "keystrokes": data["send_text"]
    }
    q_cmd = queue_item(
        len(queue),
        str(datetime.datetime.utcfromtimestamp(time.time())),
        False,
        cmd
    )
    queue.append(q_cmd)
    return ""

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route("/screenshot", methods=['POST']) 
def screenshot():
    # check if the post request has the file part
    if 'file' not in request.files:
        print('No file part')
        return redirect(request.url)
    file = request.files['file']
    # If the user does not select a file, the browser submits an
    # empty file without a filename.
    if file and allowed_file(file.filename):
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], file.filename))
        # update timestamp
        last_callback[0] = time.time()
    return '''
    <!doctype html>
    <title>Upload new File</title>
    <h1>Upload new File</h1>
    <form method=post enctype=multipart/form-data>
      <input type=file name=file>
      <input type=submit value=Upload>
    </form>
    '''

@app.route('/update-image')
def update_image():
    if last_callback[0] == 0:
        return '<img src="/static/wait_screen.png" style="max-width: 80vw; max-height: 71vh; aspect-ratio: initial;" title="screenshot" hx-get="/update-image" hx-swap="outerHTML" hx-trigger="every 5s" />'
    else:
        return '<img id="screenshot" src="/static/screenshot.png?' + str(random.random()) + '" align="middle" style="max-width: 80vw; max-height: 71vh;aspect-ratio: initial;" title="screenshot" hx-get="/update-image" hx-swap="outerHTML" hx-trigger="every 5s"/>'

# Send command to agent
@app.route("/cmd", methods=['GET']) 
def cmd():
    cmd = {
        "mouse": {
            "x": 0,
            "y": 0,
            "action": ""
        },
        "keystrokes": ""
    }
    if len(queue) != 0:
        for c in queue:
            if c.executed == False:
                cmd = c.command
                c.executed = True
                return cmd
    return cmd

@app.route("/get-agent-status")
def get_time():
    agent_status = """
<table style="margin-left: auto;
margin-right: auto; background-color: #b298cf; border-width: 2px; border-color: #122a14; border-style: solid;">
    <tr>
    <th>status</th>
    <th>last callback</th>
    </tr>
    <tr>
    <td>@status@</td>
    <td>@time@</td>
    </tr>
</table>
"""

    if last_callback[0] == 0:
        agent_status = agent_status.replace("@status@", '<img src="/static/pause.png" style="height: 20px; width:20px"/>')
        agent_status = agent_status.replace("@time@", "N/A")
    elif time.time() - last_callback[0] < 30: # 30 second timeout counter
        agent_status = agent_status.replace("@status@", '<img src="/static/online.png" style="height: 20px; width:20px"/>')
    else:
        agent_status = agent_status.replace("@status@", '<img src="/static/offline.png" style="height: 20px; width:20px"/>')

    agent_status = agent_status.replace("@time@", str(datetime.datetime.utcfromtimestamp(last_callback[0])))
    return agent_status

@app.route("/get-queue")
def get_queue():
    return render_template("log.html", queue=queue)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
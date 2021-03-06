import pandas as pd
import os
import math
from flask import Flask, request, render_template
import datetime

app = Flask(__name__)
PARKING_TICKETS_FILE = "parking_tickets.dat"
TICKET_ID = "ticketId"
PLATE = "plate"
PARKING_LOT = "parkingLot"
ENTRY_TIME = "entryTime"
IS_OUT = "isOut"
TRUE_STR = "True"
FALSE_STR = "False"
RATE = 2.5  # Price per 15 minutes


@app.route("/", methods=['GET', 'POST'])
def home():
    return render_template("index.html")


@app.route("/entry", methods=['GET', 'POST'])
def entry():
    plate = request.args.get('plate')
    parking_lot = request.args.get('parkingLot')
    if plate is None or parking_lot is None:
        return "Some of the query parameters were missing. The usage of this API is: POST /entry?plate=plate-number&parkingLot=parking-lot-number"

    ticket_id = generate_ticket_id()
    save_new_parking(ticket_id, plate, parking_lot)
    return f"Your ticket number is {ticket_id}. Save it for your exit!"


@app.route("/exit", methods=['GET', 'POST'])
def exit():
    ticket_id = request.args.get('ticketId')
    if ticket_id is None:
        return "Some of the query parameters were missing. The usage of this API is: POST /exit?ticketId=ticket-id"
    parking_details = get_parking_details(ticket_id)
    mark_ticket_exit(ticket_id)
    return parking_details


def generate_ticket_id():
    max_ticket_id = 0
    if os.path.exists(PARKING_TICKETS_FILE):
        try:
            parking_tickets = [i.strip().split("::") for i in open(PARKING_TICKETS_FILE, 'r').readlines()]
            parking_tickets_df = pd.DataFrame(parking_tickets,
                                              columns=[TICKET_ID, PLATE, PARKING_LOT, ENTRY_TIME, IS_OUT], dtype=str)
            parking_tickets_df[TICKET_ID] = parking_tickets_df[TICKET_ID].apply(pd.to_numeric)
            max_ticket_id = max(parking_tickets_df[TICKET_ID])
        except Exception as e:
            print("Exception occurred while trying to create a new ticket id:{}".format(e))
    return max_ticket_id + 1


def save_new_parking(ticket_id, plate, parking_lot):
    try:
        with open(PARKING_TICKETS_FILE, "a+") as file:
            entry_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            file.write(f"{ticket_id}::{plate}::{parking_lot}::{entry_time}::{FALSE_STR}\n")
        print("parking ticket was saved successfully")
    except Exception as e:
        print("Exception occurred while trying to save a new parking ticket:{}".format(e))


def get_parking_details(ticket_id):
    result_message = "We couldn't find your parking details. Please check that your ticket id is correct."
    if os.path.exists(PARKING_TICKETS_FILE):
        try:
            leave_time_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            parking_tickets = [i.strip().split("::") for i in open(PARKING_TICKETS_FILE, 'r').readlines()]
            parking_tickets_df = pd.DataFrame(parking_tickets,
                                              columns=[TICKET_ID, PLATE, PARKING_LOT, ENTRY_TIME, IS_OUT], dtype=str)
            if parking_tickets_df[parking_tickets_df[TICKET_ID] == ticket_id].iloc[0][IS_OUT] == TRUE_STR:
                result_message = "The car associated with this ticket id was already left the parking lot."
            else:
                parking_details = parking_tickets_df[(parking_tickets_df[TICKET_ID] == ticket_id)]
                entry_time = datetime.datetime.strptime(str(parking_details[ENTRY_TIME].iloc[0]), '%Y-%m-%d %H:%M:%S')
                leave_time = datetime.datetime.strptime(leave_time_str, '%Y-%m-%d %H:%M:%S')
                time_parked = leave_time - entry_time
                time_parked_minutes = math.ceil(time_parked.total_seconds() / 60)
                charge = math.ceil(time_parked_minutes / 15) * RATE
                result_message = f"The total parking time of license plate {parking_details[PLATE].iloc[0]} at the parking" \
                                 f" lot {parking_details[PARKING_LOT].iloc[0]} is {time_parked}. The total charge is {charge}$."
        except Exception as e:
            print("Exception occurred while trying to get the parking details:{}".format(e))
    return result_message


def mark_ticket_exit(ticket_id):
    try:
        parking_tickets = [i.strip().split("::") for i in open(PARKING_TICKETS_FILE, 'r').readlines()]
        parking_tickets_df = pd.DataFrame(parking_tickets, columns=[TICKET_ID, PLATE, PARKING_LOT, ENTRY_TIME, IS_OUT],
                                          dtype=str)
        ticket_index = parking_tickets_df.index[parking_tickets_df[TICKET_ID] == ticket_id][0]
        parking_tickets_df.at[ticket_index, IS_OUT] = TRUE_STR
        with open(PARKING_TICKETS_FILE, "w") as file:
            for index, row in parking_tickets_df.iterrows():
                file.write(f"{row[TICKET_ID]}::{row[PLATE]}::{row[PARKING_LOT]}::{row[ENTRY_TIME]}::{row[IS_OUT]}\n")
    except Exception as e:
        print(f"Exception occurred while trying to mark ticket {ticket_id} as out: {e}")


if __name__ == "__main__":
    app.run()

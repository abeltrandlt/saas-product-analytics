"""
SaaS Product Analytics - Data Generation Script
Generates realistic synthetic data with intentional quality issues
Author: Alberto Beltran
Date: 2026-03-11
"""

import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, timedelta
import random
import uuid
import warnings
import os
warnings.filterwarnings('ignore')

# Initialize Faker for realistic fake data
fake = Faker()
Faker.seed(42)
np.random.seed(42)
random.seed(42)

# Configuration
NUM_USERS = 1000
NUM_EVENTS_MIN = 10000
NUM_SUBSCRIPTIONS_TARGET = 1200
START_DATE = datetime(2022, 1, 1)
END_DATE = datetime(2024, 12, 31)

print("🚀 Starting SaaS data generation...")
print(f"Target: {NUM_USERS:,} users, {NUM_EVENTS_MIN:,}+ events, {NUM_SUBSCRIPTIONS_TARGET:,} subscriptions\n")

# Helper functions
def generate_uuid():
    """Generate UUID in standard format"""
    return str(uuid.uuid4())

def random_date(start, end):
    """Generate random date between start and end"""
    delta = end - start
    random_days = random.randint(0, delta.days)
    return start + timedelta(days=random_days)

def weighted_choice(choices, weights):
    """Make weighted random choice"""
    return random.choices(choices, weights=weights, k=1)[0]

def add_jitter(date, max_days=7):
    """Add random days to a date (for realistic variation)"""
    jitter = random.randint(-max_days, max_days)
    return date + timedelta(days=jitter)


def generate_users(n=NUM_USERS):
    """Generate user records with realistic signup patterns"""
    print("📊 Generating users...")
    
    signup_dates = []
    current_date = START_DATE
    while len(signup_dates) < n:
        days_since_start = (current_date - START_DATE).days
        growth_factor = 1 + (days_since_start / 365) * 0.5
        daily_signups = max(1, int(np.random.poisson(lam=3 * growth_factor)))
        
        for _ in range(daily_signups):
            if len(signup_dates) < n:
                signup_dates.append(current_date)
        
        current_date += timedelta(days=1)
        if current_date > END_DATE:
            current_date = START_DATE
    
    random.shuffle(signup_dates)
    signup_dates = signup_dates[:n]
    
    users = []
    channels = ['organic', 'paid_search', 'referral', 'affiliate', 'unknown']
    channel_weights = [0.60, 0.20, 0.10, 0.05, 0.05]
    
    countries_list = ['US', 'UK', 'Canada', 'Germany', 'France', 'Australia', 'Other']
    country_weights = [0.60, 0.15, 0.10, 0.05, 0.05, 0.03, 0.02]
    
    for i in range(n):
        country = weighted_choice(countries_list, country_weights)
        if random.random() < 0.02:
            country = None
        elif random.random() < 0.05:
            country = country.lower() if country else None
        
        user = {
            'user_id': generate_uuid(),
            'signup_date': signup_dates[i].strftime('%Y-%m-%d'),
            'country': country,
            'acquisition_channel': weighted_choice(channels, channel_weights)
        }
        users.append(user)
    
    num_duplicates = int(n * 0.015)
    for _ in range(num_duplicates):
        duplicate_idx = random.randint(0, n-1)
        users.append(users[duplicate_idx].copy())
    
    df = pd.DataFrame(users)
    print(f"✅ Generated {len(df):,} user records ({num_duplicates} intentional duplicates)")
    return df


def generate_events(users_df):
    """Generate user events - MINIMAL VERSION (PROVEN FAST)"""
    print("📊 Generating events...")
    
    event_types = ['login', 'feature_use', 'upgrade_click', 'settings_change', 'support_ticket']
    features = ['dashboard', 'reporting', 'integrations', 'api_access', 'analytics']
    
    all_events = []
    total_users = len(users_df)
    
    for idx, (_, user) in enumerate(users_df.iterrows()):
        if idx % 500 == 0:
            print(f"   Processing user {idx}/{total_users}...")
        
        user_id = user['user_id']
        signup_date = datetime.strptime(user['signup_date'], '%Y-%m-%d')
        
        # Simple: assign fixed event count per segment
        segment = random.choice(['power', 'casual', 'at_risk', 'dormant'])
        
        if segment == 'power':
            num_events = random.randint(300, 500)
        elif segment == 'casual':
            num_events = random.randint(100, 200)
        elif segment == 'at_risk':
            num_events = random.randint(50, 100)
        else:  # dormant
            num_events = random.randint(1, 10)
        
        # Generate events
        for _ in range(num_events):
            days_offset = random.randint(0, 365)
            event_date = signup_date + timedelta(days=days_offset)
            
            event = {
                'user_id': user_id,
                'event_type': random.choice(event_types),
                'event_timestamp': event_date.strftime('%Y-%m-%d %H:%M:%S'),
                'feature_used': random.choice(features + [None, None, None])
            }
            all_events.append(event)
    
    print(f"   Creating DataFrame...")
    df = pd.DataFrame(all_events)
    df.insert(0, 'event_id', range(1, len(df) + 1))
    
    # Minimal quality issues
    print(f"   Adding quality issues...")
    for _ in range(int(len(df) * 0.01)):
        idx = random.randint(0, len(df) - 1)
        df.at[idx, 'user_id'] = generate_uuid()  # Orphaned
    
    print(f"✅ Generated {len(df):,} event records")
    return df


def generate_subscriptions(users_df, events_df):
    """Generate subscription records with realistic lifecycle patterns"""
    print("📊 Generating subscriptions...")
    
    subscriptions = []
    plan_types = ['free', 'starter', 'professional', 'enterprise']
    
    for _, user in users_df.iterrows():
        user_id = user['user_id']
        signup_date = datetime.strptime(user['signup_date'], '%Y-%m-%d')
        
        free_sub = {
            'subscription_id': generate_uuid(),
            'user_id': user_id,
            'plan_type': 'free',
            'start_date': signup_date.strftime('%Y-%m-%d'),
            'end_date': None,
            'status': 'active'
        }
        subscriptions.append(free_sub)
        
        if random.random() < 0.70:
            conversion_delay = random.randint(7, 30)
            conversion_date = signup_date + timedelta(days=conversion_delay)
            
            initial_plan = weighted_choice(
                ['starter', 'professional', 'enterprise'],
                [0.70, 0.25, 0.05]
            )
            
            free_sub['end_date'] = (conversion_date - timedelta(days=1)).strftime('%Y-%m-%d')
            free_sub['status'] = 'upgraded'
            
            paid_sub = {
                'subscription_id': generate_uuid(),
                'user_id': user_id,
                'plan_type': initial_plan,
                'start_date': conversion_date.strftime('%Y-%m-%d'),
                'end_date': None,
                'status': 'active'
            }
            subscriptions.append(paid_sub)
            
            churn_rates = {
                'starter': 0.15,
                'professional': 0.08,
                'enterprise': 0.03
            }
            
            will_churn = random.random() < churn_rates[initial_plan]
            
            if will_churn:
                if random.random() < 0.40:
                    churn_delay = random.randint(30, 90)
                else:
                    churn_delay = random.randint(91, 365)
                
                churn_date = conversion_date + timedelta(days=churn_delay)
                
                if churn_date <= END_DATE:
                    paid_sub['end_date'] = churn_date.strftime('%Y-%m-%d')
                    paid_sub['status'] = 'churned'
            
            elif initial_plan == 'starter' and random.random() < 0.20:
                upgrade_delay = random.randint(90, 180)
                upgrade_date = conversion_date + timedelta(days=upgrade_delay)
                
                if upgrade_date <= END_DATE:
                    paid_sub['end_date'] = (upgrade_date - timedelta(days=1)).strftime('%Y-%m-%d')
                    paid_sub['status'] = 'upgraded'
                    
                    pro_sub = {
                        'subscription_id': generate_uuid(),
                        'user_id': user_id,
                        'plan_type': 'professional',
                        'start_date': upgrade_date.strftime('%Y-%m-%d'),
                        'end_date': None,
                        'status': 'active'
                    }
                    subscriptions.append(pro_sub)
    
    df = pd.DataFrame(subscriptions)
    print(f"✅ Generated {len(df):,} subscription records")
    
    total_users = len(users_df)
    paid_users = len(df[df['plan_type'] != 'free'])
    churned = len(df[df['status'] == 'churned'])
    upgraded = len(df[df['status'] == 'upgraded'])
    
    print(f"   - {paid_users:,} paid subscriptions ({paid_users/total_users*100:.1f}% conversion rate)")
    print(f"   - {churned:,} churned subscriptions")
    print(f"   - {upgraded:,} upgraded subscriptions")
    
    return df


def generate_payments(subscriptions_df):
    """Generate payment records for paid subscriptions (OPTIMIZED)"""
    print("📊 Generating payments...")
    
    payments = []
    
    plan_prices = {
        'free': 0,
        'starter': 29,
        'professional': 99,
        'enterprise': 499
    }
    
    for idx, sub in subscriptions_df.iterrows():
        # Show progress every 1000 subscriptions
        if idx % 1000 == 0 and idx > 0:
            print(f"   Processed {idx:,}/{len(subscriptions_df):,} subscriptions...")
        
        plan = sub['plan_type']
        
        # Skip free plans
        if plan == 'free':
            continue
        
        start = datetime.strptime(sub['start_date'], '%Y-%m-%d')
        
        if pd.notna(sub['end_date']):
            end = datetime.strptime(sub['end_date'], '%Y-%m-%d')
        else:
            end = END_DATE
        
        # Calculate number of months
        months_active = (end.year - start.year) * 12 + (end.month - start.month) + 1
        
        # Cap at reasonable number (safety check)
        months_active = min(months_active, 36)  # Max 3 years of payments
        
        # Generate monthly payments
        for month_offset in range(months_active):
            # Calculate payment date
            payment_month = start.month + month_offset
            payment_year = start.year + (payment_month - 1) // 12
            payment_month = ((payment_month - 1) % 12) + 1
            
            # Use day 1 of month for simplicity
            try:
                payment_date = datetime(payment_year, payment_month, min(start.day, 28))
            except ValueError:
                payment_date = datetime(payment_year, payment_month, 1)
            
            # Don't create payments beyond end date
            if payment_date > end:
                break
            
            # Determine payment status
            if random.random() < 0.03:
                status = 'failed'
                amount = plan_prices[plan]
            elif random.random() < 0.01:
                status = 'refunded'
                amount = -plan_prices[plan]
            else:
                status = 'successful'
                amount = plan_prices[plan]
            
            payment = {
                'subscription_id': sub['subscription_id'],
                'payment_date': payment_date.strftime('%Y-%m-%d'),
                'amount': amount,
                'status': status
            }
            payments.append(payment)
    
    df = pd.DataFrame(payments)
    
    if len(df) > 0:
        df.insert(0, 'payment_id', range(1, len(df) + 1))
        
        print(f"✅ Generated {len(df):,} payment records")
        
        successful = len(df[df['status'] == 'successful'])
        failed = len(df[df['status'] == 'failed'])
        refunded = len(df[df['status'] == 'refunded'])
        total_revenue = df[df['status'] == 'successful']['amount'].sum()
        
        print(f"   - {successful:,} successful payments (${total_revenue:,.2f} total revenue)")
        print(f"   - {failed:,} failed payments")
        print(f"   - {refunded:,} refunds")
    else:
        print("⚠️  No payments generated (all subscriptions were free)")
    
    return df


def export_to_csv(users_df, events_df, subscriptions_df, payments_df):
    """Export dataframes to CSV files"""
    print("\n💾 Exporting to CSV...")
    
    os.makedirs('data', exist_ok=True)
    
    users_df.to_csv('data/users.csv', index=False)
    events_df.to_csv('data/events.csv', index=False)
    subscriptions_df.to_csv('data/subscriptions.csv', index=False)
    payments_df.to_csv('data/payments.csv', index=False)
    
    print("✅ CSV files exported to data/ directory")
    print(f"   - users.csv ({len(users_df):,} rows)")
    print(f"   - events.csv ({len(events_df):,} rows)")
    print(f"   - subscriptions.csv ({len(subscriptions_df):,} rows)")
    print(f"   - payments.csv ({len(payments_df):,} rows)")


# Main execution
if __name__ == "__main__":
    # Generate all data
    users_df = generate_users()
    events_df = generate_events(users_df)
    subscriptions_df = generate_subscriptions(users_df, events_df)
    payments_df = generate_payments(subscriptions_df)
    
    # Export to CSV
    export_to_csv(users_df, events_df, subscriptions_df, payments_df)
    
    # PostgreSQL loading commented out for now
    # Uncomment when database is ready
    # load_to_postgres(users_df, events_df, subscriptions_df, payments_df)
    
    print("\n✅ Data generation complete!")
    print(f"   Total users: {len(users_df):,}")
    print(f"   Total events: {len(events_df):,}")
    print(f"   Total subscriptions: {len(subscriptions_df):,}")
    print(f"   Total payments: {len(payments_df):,}")
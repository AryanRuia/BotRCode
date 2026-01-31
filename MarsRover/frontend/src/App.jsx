import React, { useEffect, useState, useRef } from 'react'

const API_BASE = '' // same origin

export default function App(){
  const [imu, setImu] = useState(null)
  const [baro, setBaro] = useState(null)
  const [imgUrl, setImgUrl] = useState(null)
  const wsRef = useRef(null)

  useEffect(()=>{
    fetch('/api/sensors').then(r=>r.json()).then(d=>{ setImu(d.imu); setBaro(d.barometer) })
    const ws = new WebSocket((window.location.protocol==='https:'?'wss://':'ws://') + window.location.host + '/ws/telemetry')
    ws.onmessage = (ev)=>{
      try{ const msg = JSON.parse(ev.data); if(msg.type==='telemetry'){ setImu(msg.payload.imu); setBaro(msg.payload.barometer) } }catch(e){}
    }
    wsRef.current = ws
    return ()=> ws.close()
  },[])

  async function takeSnapshot(){
    const r = await fetch('/api/camera/snapshot')
    if(r.ok){
      const blob = await r.blob()
      setImgUrl(URL.createObjectURL(blob))
    }
  }

  async function sendXBee(){
    const cmd = prompt('Enter command to send to XBee')
    if(!cmd) return
    await fetch('/api/xbee/send', {method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({command: cmd})})
    alert('Sent')
  }

  return (
    <div style={{fontFamily:'Arial', padding:20}}>
      <h1>MarsRover Telemetry</h1>
      <div style={{display:'flex', gap:20}}>
        <section style={{flex:1}}>
          <h2>IMU</h2>
          <pre>{JSON.stringify(imu, null, 2)}</pre>
          <h2>Barometer</h2>
          <pre>{JSON.stringify(baro, null, 2)}</pre>
          <button onClick={takeSnapshot}>Take Snapshot</button>
          <button onClick={sendXBee} style={{marginLeft:10}}>Send XBee Command</button>
        </section>
        <section style={{width:400}}>
          <h2>Camera</h2>
          {imgUrl ? <img src={imgUrl} alt="snapshot" style={{width:'100%'}} /> : <div style={{width:'100%',height:240,background:'#eee',display:'flex',alignItems:'center',justifyContent:'center'}}>No image</div>}
        </section>
      </div>
    </div>
  )
}
